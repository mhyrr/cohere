defmodule Mix.Tasks.Cohere.Complete do
  @shortdoc "Completes a design: verifies its promises landed, flips it to accepted"

  @moduledoc """
  The complete verb of the feature loop — the land step, one command.

      $ mix cohere.complete deal-reversals

  Regenerates the map (mechanical, so it just happens), then requires:

    * the check hard-clean — drifted cards must be re-reviewed and
      accepted first, which is exactly the moment the design's durable
      decisions get distilled into the cards it anchors
    * every ref in Promised surface resolving in the compiled app — a
      design that promised `reverse_deal/1` cannot complete until
      `reverse_deal/1` exists
    * every anchored context present in the map

  Unresolved open questions warn but never block (DEC-FEA-007) —
  questions legitimately outlive features. On success the design flips
  `draft → accepted` with a dated Status log line. Accepted designs are
  immutable history: supersede them with a new design, never edit them.
  """

  use Mix.Task

  alias Cohere.{Design, Drift, Map, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, argv} = OptionParser.parse!(args, strict: [by: :string])

    slug =
      case argv do
        [slug] -> slug
        _ -> Mix.raise("usage: mix cohere.complete <slug> [--by NAME]")
      end

    project = Project.load()
    path = Path.join(Project.design_dir(project), Design.filename(slug))

    unless File.exists?(path) do
      Mix.raise("no design at #{path} — start one: mix cohere.design #{slug}")
    end

    {:ok, doc} = Design.parse(File.read!(path), path)

    unless doc.status == :draft do
      Mix.raise("#{path} is #{doc.status} — only drafts complete; supersede instead")
    end

    # The mechanical part just happens.
    Mix.Task.run("cohere.map")

    blockers =
      drift_blockers(project) ++ promise_blockers(doc) ++ anchor_blockers(project, doc)

    case blockers do
      [] ->
        warn_open_questions(doc)
        by = opts[:by] || git_user()
        File.write!(path, Design.accept(File.read!(path), Date.utc_today(), by: by))

        Mix.shell().info(
          "#{path} — accepted. The promised surface is live; the design's durable\n" <>
            "constraints belong in the intent cards of the contexts it anchors."
        )

      blockers ->
        Mix.shell().error(
          "cannot complete #{slug}:\n" <> Enum.map_join(blockers, "\n", &("  ✗ " <> &1))
        )

        exit({:shutdown, 1})
    end
  end

  # Same default as `mix cohere.check --accept`: the configured git
  # identity names who judged (DEC-AGE-004); absent, the plain form.
  defp git_user do
    case System.cmd("git", ["config", "user.name"], stderr_to_stdout: true) do
      {out, 0} -> with "" <- String.trim(out), do: nil
      _ -> nil
    end
  rescue
    ErlangError -> nil
  end

  defp drift_blockers(project) do
    report = Drift.check(project)

    if Drift.Report.clean?(report) do
      []
    else
      ["hard drift outstanding — `mix cohere.check`, fix or --accept, then retry"]
    end
  end

  defp promise_blockers(doc) do
    Enum.map(Design.unmet_promises(doc), fn
      {module, nil, nil} -> "promised `#{module}` does not exist"
      {module, fun, arity} -> "promised `#{module}.#{fun}/#{arity}` does not exist"
    end)
  end

  defp anchor_blockers(project, doc) do
    map = Map.build(project)

    doc.contexts
    |> Enum.reject(&Map.fetch_group(map, &1))
    |> Enum.map(&"anchored context \"#{&1}\" is not in the map")
  end

  defp warn_open_questions(doc) do
    case Design.open_questions(doc) do
      nil ->
        :ok

      questions ->
        Mix.shell().info(
          "⚠ open questions remain (accepted anyway — they outlive features):\n" <>
            indent(questions)
        )
    end
  end

  defp indent(text) do
    text
    |> String.split("\n")
    |> Enum.map_join("\n", &("  " <> &1))
  end
end
