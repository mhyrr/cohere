defmodule Cohere.PacketTest do
  use ExUnit.Case, async: true

  alias Cohere.{Intent, Map, Packet, Project}

  defp write_design!(project, slug, attrs) do
    dir = Project.design_dir(project)
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, slug <> ".md"), """
    ---
    design: #{slug}
    status: #{attrs[:status]}
    date: 2026-07-08
    contexts: #{attrs[:contexts]}
    ---

    # #{slug} — Design

    ## Problem

    #{attrs[:problem] || "The problem prose."}

    ## Shape

    Long shape prose that must never reach a packet.

    ## Promised surface

    <!-- template comment only — renders as absent -->
    """)
  end

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    project = Cohere.Fixtures.project(dir: tmp)
    map = Map.build(project)
    %{project: project, accounts: Enum.find(map.groups, &(&1.name == "Accounts"))}
  end

  test "assembles map slice, card, routes, and runtime guidance", %{
    project: project,
    accounts: accounts
  } do
    dir = Project.intent_dir(project)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "accounts.md"), Intent.skeleton(accounts, ~D[2026-07-02]))

    {:ok, packet} = Packet.build(project, ["accounts"])

    assert packet =~ "# Work Packet — Accounts"
    assert packet =~ "### Fixture.Accounts — domain"
    assert packet =~ "### Fixture.Accounts.User → `users`"
    # card inlined
    assert packet =~ "# Accounts — Intent"
    # name-matched routes: /users routes match token "Account"? No — but the
    # UserController doesn't contain "Account", so no routes section.
    refute packet =~ "GET /users"
    # tidewave absent in this environment → verify-via-tests guidance
    assert packet =~ "No runtime introspection detected"
  end

  test "missing card yields an honest pointer, not silence", %{project: project} do
    {:ok, packet} = Packet.build(project, ["billing"])
    assert packet =~ "No intent card for this context"
    assert packet =~ "mix cohere.gen.intent billing"
  end

  test "unknown contexts error by name" do
    project = Cohere.Fixtures.project()
    assert {:error, {:unknown_contexts, ["nope"]}} = Packet.build(project, ["nope"])
  end

  describe "design slices" do
    test "a draft anchoring several packeted contexts inlines loudly, once", %{project: project} do
      write_design!(project, "reversals",
        status: "draft",
        contexts: "accounts, billing",
        problem: "Reversals do not exist yet."
      )

      {:ok, packet} = Packet.build(project, ["accounts", "billing"])

      assert packet =~ "## In-flight designs"
      assert packet =~ "Reversals do not exist yet."
      assert packet =~ Path.join(Project.design_dir(project), "reversals.md")
      # once per packet, not once per anchored context (DEC-PAC-002)
      assert length(String.split(packet, "Reversals do not exist yet.")) == 2
      # excerpt means Problem, never Shape
      refute packet =~ "Long shape prose"
      # a comment-only Promised surface renders as absent
      refute packet =~ "**Promised surface**"
    end

    test "accepted designs are pointers, never content", %{project: project} do
      write_design!(project, "reversals",
        status: "accepted",
        contexts: "accounts",
        problem: "Accepted prose stays out of packets."
      )

      {:ok, packet} = Packet.build(project, ["accounts"])

      assert packet =~ "### Designs"
      assert packet =~ "`reversals`"
      assert packet =~ Path.join(Project.design_dir(project), "reversals.md")
      refute packet =~ "Accepted prose stays out of packets."
      refute packet =~ "## In-flight designs"
    end

    test "superseded designs and designs for other contexts never render", %{project: project} do
      write_design!(project, "old-reversals", status: "superseded", contexts: "accounts")
      write_design!(project, "billing-only", status: "draft", contexts: "billing")

      {:ok, packet} = Packet.build(project, ["accounts"])

      refute packet =~ "old-reversals"
      refute packet =~ "billing-only"
    end
  end

  describe "guidance_paths/2" do
    test "finds directory guidance via the source index, root excluded", %{
      tmp_dir: tmp,
      accounts: accounts
    } do
      dir = Path.join(tmp, "lib/fixture")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "CLAUDE.md"), "Accounts guidance.")
      File.write!(Path.join(dir, "AGENTS.md"), "Agent guidance.")
      # root guidance stays a pointer (DEC-PAC-004)
      File.write!(Path.join(tmp, "CLAUDE.md"), "Root guidance.")

      index = %{
        Path.join(dir, "accounts.ex") => [Fixture.Accounts],
        Path.join(dir, "accounts/user.ex") => [Fixture.Accounts.User],
        Path.join(tmp, "root.ex") => [Fixture.Accounts]
      }

      # relative-rooted index entry for the root-exclusion branch
      assert Packet.guidance_paths(%{"top.ex" => [Fixture.Accounts]}, accounts) == []

      paths = Packet.guidance_paths(index, accounts)

      assert Path.join(dir, "AGENTS.md") in paths
      assert Path.join(dir, "CLAUDE.md") in paths
      # tmp root's CLAUDE.md only appears because tmp is a real dir in the
      # index — the "." (project root) entry is what the pointer rule excludes
      refute "CLAUDE.md" in paths
    end

    test "modules outside the group contribute nothing", %{tmp_dir: tmp, accounts: accounts} do
      dir = Path.join(tmp, "lib/elsewhere")
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "CLAUDE.md"), "Not yours.")

      index = %{Path.join(dir, "billing.ex") => [Fixture.Billing]}

      assert Packet.guidance_paths(index, accounts) == []
    end
  end

  describe "diff-driven assembly" do
    setup %{project: project} do
      %{map: Map.build(project)}
    end

    test "group_index maps every owned module to its context", %{map: map} do
      index = Packet.group_index(map)

      assert index[Fixture.Accounts] == "Accounts"
      assert index[Fixture.Accounts.User] == "Accounts"
      assert index[Fixture.Workers.SyncWorker] == "Workers"
      # web modules belong to no domain context group
      refute Elixir.Map.has_key?(index, FixtureWeb.UserController)
    end

    test "contexts_for_files resolves, dedupes, and reports the unmapped", %{map: map} do
      index = %{
        "lib/fixture/accounts.ex" => [Fixture.Accounts],
        "lib/fixture/accounts/user.ex" => [Fixture.Accounts.User],
        "lib/fixture/billing.ex" => [Fixture.Billing],
        "lib/fixture_web/router.ex" => [FixtureWeb.Router]
      }

      files = [
        "lib/fixture/accounts.ex",
        "lib/fixture/accounts/user.ex",
        "lib/fixture/billing.ex",
        "lib/fixture_web/router.ex",
        "config/config.exs"
      ]

      report = Packet.contexts_for_files(map, index, files)

      # Accounts appears once despite two files touching it; order is first-seen.
      assert report.contexts == ["Accounts", "Billing"]
      # a mapped-but-web file and an unindexed file both surface as unmapped
      assert report.unmapped == ["lib/fixture_web/router.ex", "config/config.exs"]
    end

    test "build_for_files assembles a scoped packet from real reflection", %{project: project} do
      # Every fixture module compiles from this one support file, so it stands
      # in for a branch that touched the whole domain layer.
      {:ok, packet, report} = Packet.build_for_files(project, ["test/support/fixtures.ex"])

      assert "Accounts" in report.contexts
      assert "Billing" in report.contexts
      assert packet =~ "**Branch scope**"
      assert packet =~ "Contexts touched:"
      assert packet =~ "### Fixture.Accounts.User → `users`"
    end

    test "build_for_files errors honestly when nothing maps", %{project: project} do
      assert {:error, {:no_contexts, ["priv/repo/migrations/001_init.exs"]}} =
               Packet.build_for_files(project, ["priv/repo/migrations/001_init.exs"])
    end
  end
end
