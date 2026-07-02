defmodule Cohere.DriftTest do
  use ExUnit.Case, async: true

  alias Cohere.{Drift, Intent, Map, Project}
  alias Cohere.Map.Renderer

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    project = Cohere.Fixtures.project(dir: tmp)
    map = Map.build(project)
    %{project: project, map: map, accounts: Enum.find(map.groups, &(&1.name == "Accounts"))}
  end

  defp write_map!(project, contents), do: File.write!(Project.map_path(project), contents)

  defp write_card!(project, name, contents) do
    dir = Project.intent_dir(project)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, name), contents)
  end

  test "missing map", %{project: project} do
    report = Drift.check(project)
    assert report.map_status == :missing
    refute Drift.Report.clean?(report)
  end

  test "fresh map and in-sync card is clean", %{project: project, map: map, accounts: accounts} do
    write_map!(project, Renderer.render(map))
    write_card!(project, "accounts.md", Intent.skeleton(accounts, ~D[2026-07-02]))

    report = Drift.check(project)
    assert report.map_status == :fresh
    assert [%{issues: []}] = report.cards
    assert Drift.Report.clean?(report)
    assert Drift.format(report) =~ "coherent: no drift detected"
  end

  test "stale map produces a bounded line diff", %{project: project, map: map} do
    write_map!(project, Renderer.render(map) <> "\nstale trailing line\n")

    report = Drift.check(project)
    assert report.map_status == :stale
    assert "- stale trailing line" in report.map_diff
    assert Drift.format(report) =~ "map is stale"
  end

  test "surface drift on a card reports added and removed", %{
    project: project,
    map: map,
    accounts: accounts
  } do
    write_map!(project, Renderer.render(map))

    stale_card = """
    ---
    context: Fixture.Accounts
    reviewed: 2026-01-01
    surface: 000000000000
    functions: create_user/1 old_fun/3
    ---

    ## Purpose

    Own the account lifecycle.
    """

    write_card!(project, "accounts.md", stale_card)

    report = Drift.check(project)
    [%{issues: [{:drifted, added, removed}]}] = report.cards

    assert {:old_fun, 3} in removed
    assert {:list_users, 0} in added
    assert {:create_user, 1} not in added
    refute Drift.Report.clean?(report)
    assert Drift.format(report) =~ "--accept accounts"
    _ = accounts
  end

  test "cards pointing at dead contexts and dead functions", %{project: project, map: map} do
    write_map!(project, Renderer.render(map))

    write_card!(project, "ghost.md", """
    ---
    context: Fixture.Ghost
    reviewed: 2026-01-01
    surface: 000000000000
    functions:
    ---

    ## Purpose

    A context that no longer exists. Also references
    `Fixture.Accounts.no_such_fun/9` and `Fixture.Nope`.
    """)

    report = Drift.check(project)
    [%{issues: issues}] = report.cards

    assert {:missing_context, Fixture.Ghost} in issues
    assert Enum.any?(issues, &match?({:broken_ref, "Fixture.Accounts.no_such_fun/9" <> _}, &1))
    assert Enum.any?(issues, &match?({:broken_ref, "Fixture.Nope" <> _}, &1))
  end

  test "contexts without cards are informational, not drift", %{
    project: project,
    map: map,
    accounts: accounts
  } do
    write_map!(project, Renderer.render(map))
    write_card!(project, "accounts.md", Intent.skeleton(accounts, ~D[2026-07-02]))

    report = Drift.check(project)
    assert Fixture.Billing in report.uncarded
    assert Drift.Report.clean?(report)
  end
end
