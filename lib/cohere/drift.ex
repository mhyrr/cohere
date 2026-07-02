defmodule Cohere.Drift do
  @moduledoc """
  The drift sentinel: mechanically detects when the project has moved out
  from under its coherence artifacts.

  Three checks, all deterministic:

    1. **Stale map** — the committed `cohere/map.md` no longer matches a
       fresh derivation. The code changed shape; the map needs regenerating.
    2. **Drifted cards** — a context's public surface no longer matches the
       surface its intent card was reviewed against. Someone (or something)
       must re-review: fix the card, or accept the drift with a dated
       annotation.
    3. **Broken references** — a card mentions `MyApp.Module` or
       `MyApp.Module.fun/1` that no longer exists.

  Accepted drift is documented drift; silent drift is the failure mode.
  """

  alias Cohere.{Intent, Map, Project}
  alias Cohere.Map.Renderer

  defmodule Report do
    @moduledoc false
    defstruct map_status: :missing,
              map_diff: [],
              cards: [],
              uncarded: []

    def clean?(%__MODULE__{} = report) do
      report.map_status == :fresh and Enum.all?(report.cards, &(&1.issues == []))
    end
  end

  @max_diff_lines 40

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
      uncarded: uncarded(map, cards)
    }
  end

  @doc "Formats a report for terminal/CI output."
  def format(%Report{} = report) do
    [
      map_section(report),
      Enum.map(report.cards, &card_section/1),
      uncarded_section(report),
      verdict(report)
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
            "  → re-review the card, then `mix cohere.drift --accept #{card_slug(status.card)}`"

        {:broken_ref, ref} ->
          "  broken reference: #{ref}"
      end)

    Enum.join([header | details], "\n")
  end

  defp uncarded_section(%Report{uncarded: []}), do: nil

  defp uncarded_section(%Report{uncarded: contexts}) do
    names = Enum.map_join(contexts, ", ", &inspect/1)
    "ℹ contexts without intent cards (optional): #{names}"
  end

  defp verdict(report) do
    if Report.clean?(report) do
      "\ncoherent: no drift detected"
    else
      "\ndrift detected"
    end
  end

  defp card_name(card), do: card.path || inspect(card.context)

  defp card_slug(%{path: nil, context: context}) do
    context |> Module.split() |> List.last() |> Macro.underscore()
  end

  defp card_slug(%{path: path}), do: Path.basename(path, ".md")
end
