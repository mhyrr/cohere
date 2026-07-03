defmodule Cohere.Check do
  @moduledoc """
  The check verb: every finding cohere can make, in one iterative command —
  the same command locally and in CI. Fix what it lists, run it again.

  Two severities. **Hard** findings fail the build (exit 1), unchanged
  from the drift sentinel: stale map, drifted intent cards, broken card
  references. **Soft** findings are advisories and never fail: design
  anchors that don't resolve to the map, dead references in design prose,
  drafts in flight. Designs never gate the build (DEC-FEA-002): drift on
  history is information; drift on intent is a bug.
  """

  alias Cohere.{Design, Drift, Map, Project}

  defmodule Report do
    @moduledoc false
    defstruct drift: nil, designs: []

    def clean?(%__MODULE__{drift: drift}), do: Drift.Report.clean?(drift)
  end

  @doc "Runs every check. Only `report.drift` carries build-failing findings."
  @spec check(Project.t()) :: Report.t()
  def check(%Project{} = project) do
    map = Map.build(project)

    designs =
      project
      |> Design.load_all()
      |> Enum.map(&%{doc: &1, issues: Design.issues(&1, map, project)})

    %Report{drift: Drift.check(project), designs: designs}
  end

  @doc "Formats the combined report for terminal/CI output."
  def format(%Report{} = report) do
    [
      Drift.format(report.drift),
      designs_section(report.designs),
      verdict(report)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp designs_section([]), do: nil

  defp designs_section(designs) do
    Enum.map_join(designs, "\n", &design_line/1)
  end

  defp design_line(%{doc: doc, issues: []}) do
    "✓ #{doc.path} — #{doc.status}#{in_flight(doc)}"
  end

  defp design_line(%{doc: doc, issues: issues}) do
    header = "⚠ #{doc.path} — #{doc.status}, advisory only"
    Enum.join([header | Enum.map(issues, &issue_line/1)], "\n")
  end

  defp in_flight(%{status: :draft, slug: slug}) do
    " (in flight — `mix cohere.complete #{slug}` when built)"
  end

  defp in_flight(_doc), do: ""

  defp issue_line({:anchor_missing, name}) do
    "  anchor \"#{name}\" not in the map — fine if this design introduces it; " <>
      "`mix cohere.complete` verifies it lands"
  end

  defp issue_line({:broken_ref, ref}) do
    "  dead reference `#{ref}` — fix it, or move it to Promised surface if it is still to build"
  end

  defp verdict(%Report{} = report) do
    advisories = Enum.count(report.designs, &(&1.issues != []))

    cond do
      not Report.clean?(report) -> "\ndrift detected"
      advisories > 0 -> "\ncoherent: no drift detected (#{advisories} design advisory/ies above)"
      true -> "\ncoherent: no drift detected"
    end
  end
end
