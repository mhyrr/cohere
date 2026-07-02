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
end
