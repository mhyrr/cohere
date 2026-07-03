defmodule Cohere.CheckTest do
  use ExUnit.Case, async: true

  alias Cohere.{Check, Design, Intent, Map, Project}
  alias Cohere.Map.Renderer

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    project = Cohere.Fixtures.project(dir: tmp)
    map = Map.build(project)
    %{project: project, map: map, accounts: Enum.find(map.groups, &(&1.name == "Accounts"))}
  end

  defp make_coherent!(project, map, accounts) do
    File.write!(Project.map_path(project), Renderer.render(map))
    dir = Project.intent_dir(project)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "accounts.md"), Intent.skeleton(accounts, ~D[2026-07-03]))
  end

  defp write_design!(project, slug, contents) do
    dir = Project.design_dir(project)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, Design.filename(slug)), contents)
  end

  test "design advisories never fail the build", %{
    project: project,
    map: map,
    accounts: accounts
  } do
    make_coherent!(project, map, accounts)

    write_design!(project, "new-thing", """
    ---
    design: new-thing
    status: draft
    contexts: Accounts, Ghost
    ---

    ## Shape

    Uses `Fixture.Accounts.gone_fun/9`.

    ## Promised surface

    - `Fixture.Ghost.new_fun/1`
    """)

    report = Check.check(project)

    assert Check.Report.clean?(report)
    assert [%{issues: issues}] = report.designs
    assert {:anchor_missing, "Ghost"} in issues

    output = Check.format(report)
    assert output =~ "advisory only"
    assert output =~ ~s(anchor "Ghost" not in the map)
    assert output =~ "dead reference `Fixture.Accounts.gone_fun/9`"
    assert output =~ "coherent: no drift detected (1 design advisory"
  end

  test "hard drift still fails through the composed report", %{project: project} do
    # no map written → map missing → hard
    report = Check.check(project)
    refute Check.Report.clean?(report)
    assert Check.format(report) =~ "drift detected"
  end

  test "a clean draft shows as in flight with its landing command", %{
    project: project,
    map: map,
    accounts: accounts
  } do
    make_coherent!(project, map, accounts)

    write_design!(
      project,
      "feature-x",
      Design.skeleton("feature-x", ~D[2026-07-03], contexts: ["Accounts"])
    )

    output = project |> Check.check() |> Check.format()

    assert output =~ "✓"
    assert output =~ "feature-x.md — draft (in flight — `mix cohere.complete feature-x`"
    assert output =~ "coherent: no drift detected"
    refute output =~ "advisory"
  end

  test "no designs means no design section, verdict unchanged", %{
    project: project,
    map: map,
    accounts: accounts
  } do
    make_coherent!(project, map, accounts)

    output = project |> Check.check() |> Check.format()
    assert output =~ "coherent: no drift detected"
    refute output =~ "in flight"
  end
end
