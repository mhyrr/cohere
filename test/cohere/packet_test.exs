defmodule Cohere.PacketTest do
  use ExUnit.Case, async: true

  alias Cohere.{Intent, Map, Packet, Project}

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
