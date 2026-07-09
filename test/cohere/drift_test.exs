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

  describe "derived artifacts" do
    defp registration(tmp) do
      {"fake site", Path.join(tmp, "site"), {Cohere.Fixtures.FakeArtifact, :render},
       "mix run fake/build.exs"}
    end

    defp commit_fresh!(tmp) do
      Cohere.Fixtures.FakeArtifact.render(Path.join(tmp, "site"))
    end

    test "fresh when committed tree matches the render byte-for-byte", %{tmp_dir: tmp} do
      commit_fresh!(tmp)
      project = Cohere.Fixtures.project(dir: tmp, derived: [registration(tmp)])

      assert %{status: :fresh, delta: []} = Drift.derived_status(project, registration(tmp))
    end

    test "stale with a file-level delta, and it fails the gate", %{
      tmp_dir: tmp,
      map: map
    } do
      commit_fresh!(tmp)
      site = Path.join(tmp, "site")
      File.write!(Path.join(site, "page.md"), "content v1\n")
      File.write!(Path.join(site, "extra.html"), "hand-added\n")
      File.rm!(Path.join(site, "sub/nested.txt"))

      project = Cohere.Fixtures.project(dir: tmp, derived: [registration(tmp)])
      write_map!(project, Renderer.render(map))

      report = Drift.check(project)
      refute Drift.Report.clean?(report)

      assert [%{status: :stale, delta: delta, fix: "mix run fake/build.exs"}] = report.derived
      assert {:differs, "page.md"} in delta
      assert {:vanishes, "extra.html"} in delta
      assert {:appears, "sub/nested.txt"} in delta

      formatted = Drift.format(report)
      assert formatted =~ "✗ fake site"
      assert formatted =~ "→ mix run fake/build.exs, then commit the diff"
    end

    test "missing committed path is its own status", %{tmp_dir: tmp} do
      project = Cohere.Fixtures.project(dir: tmp)
      assert %{status: :missing} = Drift.derived_status(project, registration(tmp))
    end

    test "single-file artifacts compare against their basename", %{tmp_dir: tmp} do
      file = Path.join(tmp, "page.md")
      reg = {"one file", file, {Cohere.Fixtures.FakeArtifact, :render}, "rebuild"}
      project = Cohere.Fixtures.project(dir: tmp)

      File.write!(file, "content v2\n")
      assert %{status: :fresh} = Drift.derived_status(project, reg)

      File.write!(file, "content v1\n")
      assert %{status: :stale, delta: [{:differs, "page.md"}]} =
               Drift.derived_status(project, reg)
    end

    test "malformed registration raises with the expected shape", %{tmp_dir: tmp} do
      project = Cohere.Fixtures.project(dir: tmp)

      assert_raise ArgumentError, ~r/malformed derived-artifact registration/, fn ->
        Drift.derived_status(project, {"bad", "path"})
      end
    end
  end

  test "fresh map and in-sync card is clean", %{project: project, map: map, accounts: accounts} do
    write_map!(project, Renderer.render(map))
    write_card!(project, "accounts.md", Intent.skeleton(accounts, ~D[2026-07-02]))

    report = Drift.check(project)
    assert report.map_status == :fresh
    assert [%{issues: []}] = report.cards
    assert Drift.Report.clean?(report)
    assert Drift.format(report) =~ "in sync"
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
