defmodule Mix.Tasks.Cohere do
  @shortdoc "Reports where the project stands on the coherence ladder"

  @moduledoc """
  Prints the project's current coherence level and what the next rung
  requires.

      $ mix cohere

  Levels: 1 static guidance, 2 derived map, 3 checked intent cards,
  4 governed verbs / runtime verification, 5 delivered context (packets).

  Registered derived artifacts (`config :cohere, derived:`) count toward
  the L2 rung — they are the map's discipline applied to other committed
  outputs — and are listed with their freshness below the ladder.
  """

  use Mix.Task

  alias Cohere.{Design, Drift, Intent, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    unless args == [] do
      Mix.raise(
        "mix cohere takes no arguments. Try: mix cohere.design (list designs), " <>
          "mix cohere.check (the gate), mix cohere.complete <slug> (land a draft)"
      )
    end

    project = Project.load()
    report = Drift.check(project)
    cards = Intent.load_all(project)
    designs = Design.load_all(project)

    guidance = Enum.filter(["AGENTS.md", "CLAUDE.md", "usage-rules.md"], &File.exists?/1)

    rungs = [
      {1, "static guidance", level1(guidance)},
      {2, "derived map", level2(report)},
      {3, "authored intent, checked", level3(cards, report)},
      {4, "governed verbs / runtime verification", level4(project)},
      {5, "delivered context", {:ok, "work packets available via `mix cohere.packet`"}}
    ]

    Mix.shell().info("Coherence ladder — #{project.app}\n")

    Enum.each(rungs, fn {level, name, status} ->
      {mark, note} =
        case status do
          {:ok, note} -> {"✓", note}
          {:partial, note} -> {"~", note}
          {:missing, note} -> {"✗", note}
        end

      Mix.shell().info("  #{mark} L#{level} #{name} — #{note}")
    end)

    level =
      rungs
      |> Enum.take_while(fn {_, _, status} -> elem(status, 0) in [:ok, :partial] end)
      |> List.last()

    case level do
      {n, _, _} -> Mix.shell().info("\ncurrent level: #{n}")
      nil -> Mix.shell().info("\ncurrent level: 0 — start with `mix cohere.init`")
    end

    designs_line(designs)
    artifacts_line(report.derived)
  end

  # Same rule as designs: quiet only when nothing is registered.
  defp artifacts_line([]), do: :ok

  defp artifacts_line(derived) do
    list =
      Enum.map_join(derived, ", ", fn a ->
        "#{a.name} (#{a.path}) — #{a.status}"
      end)

    Mix.shell().info("derived artifacts: #{list}")
  end

  # Affirmative either way: "nothing in flight" must be distinguishable
  # from "designs unused". Quiet only when there are no designs at all.
  defp designs_line([]), do: :ok

  defp designs_line(designs) do
    drafts = Enum.filter(designs, &(&1.status == :draft))
    settled = length(designs) - length(drafts)

    case drafts do
      [] ->
        Mix.shell().info("designs: #{settled} accepted/superseded, none in flight")

      drafts ->
        flights =
          Enum.map_join(drafts, ", ", fn doc ->
            "#{doc.slug} (draft since #{doc.date} — `mix cohere.complete #{doc.slug}` when built)"
          end)

        Mix.shell().info("designs: #{length(drafts)} in flight, #{settled} settled")
        Mix.shell().info("in flight: #{flights}")
    end

    recent_designs_line(designs)
  end

  # The three newest by frontmatter date (the design's start date — the
  # only date every doc carries), stable within a day by filename order.
  defp recent_designs_line(designs) do
    recent =
      designs
      |> Enum.sort_by(&(&1.date || ""), :desc)
      |> Enum.take(3)
      |> Enum.map_join(", ", &"#{&1.slug} (#{&1.status}, #{&1.date})")

    Mix.shell().info("recent: #{recent}")
  end

  defp level1([]), do: {:missing, "no AGENTS.md / CLAUDE.md / usage-rules.md"}
  defp level1(files), do: {:ok, Enum.join(files, ", ")}

  defp level2(%{map_status: :fresh, derived: derived}) do
    case Enum.count(derived, &(&1.status != :fresh)) do
      0 -> {:ok, "map#{fresh_artifacts_note(derived)} fresh"}
      n -> {:partial, "map fresh; #{n} derived artifact(s) stale — `mix cohere.check`"}
    end
  end

  defp level2(%{map_status: :stale}), do: {:partial, "map present but stale — `mix cohere.map`"}
  defp level2(%{map_status: :missing}), do: {:missing, "no map — `mix cohere.map`"}

  defp fresh_artifacts_note([]), do: " present and"
  defp fresh_artifacts_note(derived), do: " + #{length(derived)} derived artifact(s)"

  defp level3([], _report), do: {:missing, "no intent cards — `mix cohere.gen.intent <context>`"}

  defp level3(cards, report) do
    drifted = Enum.count(report.cards, &(&1.issues != []))

    if drifted == 0 do
      {:ok, "#{length(cards)} card(s), all in sync"}
    else
      {:partial, "#{length(cards)} card(s), #{drifted} drifted — `mix cohere.check`"}
    end
  end

  defp level4(project) do
    boundary = Project.has?(project, :boundary)
    tidewave = Project.has?(project, :tidewave)

    case {boundary, tidewave} do
      {true, true} ->
        {:ok, "boundary + tidewave installed"}

      {true, false} ->
        {:partial, "boundary installed; no runtime introspection (tidewave)"}

      {false, true} ->
        {:partial, "tidewave installed; write paths not compiler-governed (boundary)"}

      {false, false} ->
        {:missing, "neither boundary nor tidewave installed"}
    end
  end
end
