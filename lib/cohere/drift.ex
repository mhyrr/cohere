defmodule Cohere.Drift do
  @moduledoc """
  The drift sentinel: mechanically detects when the project has moved out
  from under its coherence artifacts.

  Four checks, all deterministic:

    1. **Stale map** — the committed `cohere/map.md` no longer matches a
       fresh derivation. The code changed shape; the map needs regenerating.
    2. **Drifted cards** — a context's public surface no longer matches the
       surface its intent card was reviewed against. Someone (or something)
       must re-review: fix the card, or accept the drift with a dated
       annotation.
    3. **Broken references** — a card mentions `MyApp.Module` or
       `MyApp.Module.fun/1` that no longer exists.
    4. **Stale derived artifacts** — a registered generated-and-committed
       output (`config :cohere, derived: [...]`) no longer matches a fresh
       render. The map generalized: same severity, same byte-compare
       (DEC-DER-001 in `cohere/design/derived-artifacts.md`).

  Accepted drift is documented drift; silent drift is the failure mode.
  """

  alias Cohere.{Intent, Map, Project}
  alias Cohere.Map.Renderer

  defmodule Report do
    @moduledoc false
    defstruct map_status: :missing,
              map_diff: [],
              cards: [],
              uncarded: [],
              derived: []

    def clean?(%__MODULE__{} = report) do
      report.map_status == :fresh and
        Enum.all?(report.cards, &(&1.issues == [])) and
        Enum.all?(report.derived, &(&1.status == :fresh))
    end
  end

  @max_diff_lines 40
  @max_delta_entries 20

  @doc "Runs all drift checks. Returns a `%Report{}`."
  @spec check(Project.t()) :: Report.t()
  def check(%Project{} = project) do
    map = Map.build(project)
    fresh = Renderer.render(map)
    cards = Intent.load_all(project)

    %Report{
      map_status: map_status(project, fresh),
      map_diff: map_diff(project, fresh),
      cards: Enum.map(cards, &card_status(&1, map, project)),
      uncarded: uncarded(map, cards),
      derived: Enum.map(project.derived, &derived_status(project, &1))
    }
  end

  @doc """
  Freshness of one registered derived artifact: renders it into a scratch
  directory under the build path (never the working tree) and
  byte-compares the tree against the committed `path`.

  The registration is `{name, path, {module, function}, fix}` where
  `function(out_dir)` renders the artifact as it would appear at `path`,
  and `fix` is the command the finding prints. Returns
  `%{name, path, status: :fresh | :stale | :missing, delta, more, fix}`
  with a bounded file-level delta (DEC-DER-004: which files differ,
  appear, or vanish — the fixing command is the payload).
  """
  @spec derived_status(Project.t(), {String.t(), String.t(), {module(), atom()}, String.t()}) ::
          map()
  def derived_status(%Project{}, {name, path, {mod, fun}, fix}) do
    scratch = Path.join([Mix.Project.build_path(), "cohere_derived", slugify(name)])
    File.rm_rf!(scratch)
    File.mkdir_p!(scratch)
    apply(mod, fun, [scratch])

    delta = tree_delta(path, scratch)

    status =
      cond do
        not File.exists?(path) -> :missing
        delta == [] -> :fresh
        true -> :stale
      end

    %{
      name: name,
      path: path,
      status: status,
      delta: Enum.take(delta, @max_delta_entries),
      more: max(0, length(delta) - @max_delta_entries),
      fix: fix
    }
  end

  def derived_status(%Project{}, other) do
    raise ArgumentError,
          "malformed derived-artifact registration: #{inspect(other)} — expected " <>
            "{name, path, {module, function}, fix} per cohere/design/derived-artifacts.md"
  end

  # A registered path is a directory (compare trees) or a single file
  # (compare it against its basename in the scratch render).
  defp tree_delta(committed_root, fresh_root) do
    if File.regular?(committed_root) do
      rel = Path.basename(committed_root)
      fresh_file = Path.join(fresh_root, rel)

      cond do
        not File.exists?(fresh_file) -> [{:vanishes, rel}]
        File.read!(committed_root) != File.read!(fresh_file) -> [{:differs, rel}]
        true -> []
      end
    else
      committed = tree_files(committed_root)
      fresh = tree_files(fresh_root)

      differs =
        for rel <- MapSet.intersection(committed, fresh),
            File.read!(Path.join(committed_root, rel)) != File.read!(Path.join(fresh_root, rel)),
            do: {:differs, rel}

      vanishes = for rel <- MapSet.difference(committed, fresh), do: {:vanishes, rel}
      appears = for rel <- MapSet.difference(fresh, committed), do: {:appears, rel}

      Enum.sort_by(differs ++ vanishes ++ appears, &elem(&1, 1))
    end
  end

  defp tree_files(root) do
    if File.dir?(root) do
      root
      |> Path.join("**")
      |> Path.wildcard(match_dot: true)
      |> Enum.filter(&File.regular?/1)
      |> MapSet.new(&Path.relative_to(&1, root))
    else
      MapSet.new()
    end
  end

  defp slugify(name), do: String.replace(name, ~r/[^A-Za-z0-9]+/, "-")

  @doc """
  Formats a report's findings for terminal/CI output. No verdict line —
  `Cohere.Check.format/1` owns the verdict, since drift findings are one
  category among the checks it composes.
  """
  def format(%Report{} = report) do
    [
      map_section(report),
      Enum.map(report.derived, &derived_section/1),
      Enum.map(report.cards, &card_section/1),
      uncarded_section(report)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp map_status(project, fresh) do
    case File.read(Project.map_path(project)) do
      {:ok, ^fresh} -> :fresh
      {:ok, _stale} -> :stale
      {:error, _} -> :missing
    end
  end

  defp map_diff(project, fresh) do
    case File.read(Project.map_path(project)) do
      {:ok, committed} when committed != fresh ->
        committed
        |> String.split("\n")
        |> List.myers_difference(String.split(fresh, "\n"))
        |> Enum.flat_map(fn
          {:eq, _lines} -> []
          {:del, lines} -> Enum.map(lines, &("- " <> &1))
          {:ins, lines} -> Enum.map(lines, &("+ " <> &1))
        end)
        |> Enum.reject(&(String.trim(&1) in ["-", "+"]))
        |> Enum.take(@max_diff_lines)

      _ ->
        []
    end
  end

  defp card_status(card, map, project) do
    group = Enum.find(map.groups, &(&1.context == card.context))

    issues =
      context_issues(card, group) ++ ref_issues(card, project)

    %{card: card, group: group, issues: issues}
  end

  defp context_issues(card, nil) do
    [{:missing_context, card.context}]
  end

  defp context_issues(card, group) do
    if group.surface_hash == card.surface do
      []
    else
      added = group.functions -- card.functions
      removed = card.functions -- group.functions
      [{:drifted, added, removed}]
    end
  end

  defp ref_issues(card, project) do
    card
    |> Intent.refs(project.namespace)
    |> Enum.flat_map(fn {module_name, fun, arity} ->
      module = Module.concat([module_name])

      cond do
        not Code.ensure_loaded?(module) ->
          [{:broken_ref, "#{module_name} (module not found)"}]

        fun && not function_exported?(module, String.to_atom(fun), arity) ->
          [{:broken_ref, "#{module_name}.#{fun}/#{arity} (function not exported)"}]

        true ->
          []
      end
    end)
  end

  defp uncarded(map, cards) do
    carded = MapSet.new(cards, & &1.context)

    map.groups
    |> Enum.filter(&(&1.context && not MapSet.member?(carded, &1.context)))
    |> Enum.map(& &1.context)
  end

  # -- formatting -------------------------------------------------------------

  defp map_section(%Report{map_status: :fresh}), do: "✓ map is fresh"

  defp map_section(%Report{map_status: :missing}) do
    "✗ map is missing — run `mix cohere.map`"
  end

  defp map_section(%Report{map_status: :stale, map_diff: diff}) do
    truncated = if length(diff) >= @max_diff_lines, do: "\n  … (truncated)", else: ""

    "✗ map is stale — run `mix cohere.map` and commit the diff\n" <>
      Enum.map_join(diff, "\n", &("  " <> &1)) <> truncated
  end

  defp derived_section(%{status: :fresh} = artifact) do
    "✓ #{artifact.name} (#{artifact.path}) — fresh"
  end

  defp derived_section(%{status: :missing} = artifact) do
    "✗ #{artifact.name} — #{artifact.path} is missing\n  → #{artifact.fix}, then commit"
  end

  defp derived_section(%{status: :stale} = artifact) do
    delta_lines =
      Enum.map(artifact.delta, fn
        {:differs, rel} -> "  ~ #{rel}"
        {:appears, rel} -> "  + #{rel} (appears on rebuild)"
        {:vanishes, rel} -> "  − #{rel} (vanishes on rebuild)"
      end)

    more = if artifact.more > 0, do: ["  … and #{artifact.more} more file(s)"], else: []

    Enum.join(
      ["✗ #{artifact.name} (#{artifact.path}) — stale" | delta_lines] ++
        more ++ ["  → #{artifact.fix}, then commit the diff"],
      "\n"
    )
  end

  defp card_section(%{issues: []} = status) do
    "✓ #{card_name(status.card)} — in sync"
  end

  defp card_section(status) do
    header = "✗ #{card_name(status.card)}"

    details =
      Enum.map(status.issues, fn
        {:missing_context, context} ->
          "  context #{inspect(context)} no longer exists (renamed or removed?)"

        {:drifted, added, removed} ->
          added = Enum.map(added, fn {f, a} -> "+#{f}/#{a}" end)
          removed = Enum.map(removed, fn {f, a} -> "−#{f}/#{a}" end)

          "  surface drifted: #{Enum.join(added ++ removed, " ")}\n" <>
            "  → re-review the card, then `mix cohere.check --accept #{card_slug(status.card)}`"

        {:broken_ref, ref} ->
          "  broken reference: #{ref}"
      end)

    Enum.join([header | details], "\n")
  end

  defp uncarded_section(%Report{uncarded: []}), do: nil

  defp uncarded_section(%Report{uncarded: contexts}) do
    shown = Enum.map_join(Enum.take(contexts, 6), ", ", &inspect/1)

    rest =
      case length(contexts) - 6 do
        n when n > 0 -> ", …and #{n} more"
        _ -> ""
      end

    "ℹ #{length(contexts)} context(s) without intent cards (optional): #{shown}#{rest}"
  end

  defp card_name(card), do: card.path || inspect(card.context)

  defp card_slug(%{path: nil, context: context}) do
    context |> Module.split() |> List.last() |> Macro.underscore()
  end

  defp card_slug(%{path: path}), do: Path.basename(path, ".md")
end
