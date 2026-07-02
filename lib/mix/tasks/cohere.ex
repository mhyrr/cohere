defmodule Mix.Tasks.Cohere do
  @shortdoc "Reports where the project stands on the coherence ladder"

  @moduledoc """
  Prints the project's current coherence level and what the next rung
  requires.

      $ mix cohere

  Levels: 1 static guidance, 2 derived map, 3 checked intent cards,
  4 governed verbs / runtime verification, 5 delivered context (packets).
  """

  use Mix.Task

  alias Cohere.{Drift, Intent, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    project = Project.load()
    report = Drift.check(project)
    cards = Intent.load_all(project)

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
  end

  defp level1([]), do: {:missing, "no AGENTS.md / CLAUDE.md / usage-rules.md"}
  defp level1(files), do: {:ok, Enum.join(files, ", ")}

  defp level2(%{map_status: :fresh}), do: {:ok, "map present and fresh"}
  defp level2(%{map_status: :stale}), do: {:partial, "map present but stale — `mix cohere.map`"}
  defp level2(%{map_status: :missing}), do: {:missing, "no map — `mix cohere.map`"}

  defp level3([], _report), do: {:missing, "no intent cards — `mix cohere.gen.intent <context>`"}

  defp level3(cards, report) do
    drifted = Enum.count(report.cards, &(&1.issues != []))

    if drifted == 0 do
      {:ok, "#{length(cards)} card(s), all in sync"}
    else
      {:partial, "#{length(cards)} card(s), #{drifted} drifted — `mix cohere.drift`"}
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
