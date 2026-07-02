defmodule Cohere.IntentTest do
  use ExUnit.Case, async: true

  alias Cohere.{Intent, Map}

  setup do
    map = Map.build(Cohere.Fixtures.project())
    %{accounts: Enum.find(map.groups, &(&1.name == "Accounts"))}
  end

  test "skeleton is born non-drifted: parses back to the current surface", %{accounts: group} do
    {:ok, card} = group |> Intent.skeleton(~D[2026-07-02]) |> Intent.parse()

    assert card.context == Fixture.Accounts
    assert card.reviewed == "2026-07-02"
    assert card.surface == group.surface_hash
    assert card.functions == group.functions
  end

  test "parses sections by heading", %{accounts: group} do
    text = """
    ---
    context: Fixture.Accounts
    reviewed: 2026-07-02
    surface: #{group.surface_hash}
    functions: #{Cohere.Surface.to_line(group.functions)}
    ---

    # Accounts — Intent

    ## Purpose

    Own the account lifecycle.

    ## Invariants

    - INV-ACC-001: every user has an email.
    """

    {:ok, card} = Intent.parse(text)
    assert card.sections["Purpose"] == "Own the account lifecycle."
    assert card.sections["Invariants"] =~ "INV-ACC-001"
  end

  test "rejects text without frontmatter" do
    assert {:error, :no_frontmatter} = Intent.parse("# Just markdown")
  end

  test "extracts only namespaced, backticked references" do
    text = """
    ---
    context: Fixture.Accounts
    ---

    See `Fixture.Accounts.create_user/1` and `Fixture.Billing`. Ignore
    `Enum.map/2`, `String`, and plain Fixture.Accounts without backticks.
    """

    {:ok, card} = Intent.parse(text)

    assert Intent.refs(card, Fixture) == [
             {"Fixture.Accounts", "create_user", 1},
             {"Fixture.Billing", nil, nil}
           ]
  end

  test "accept_drift rebinds frontmatter and annotates", %{accounts: group} do
    stale = """
    ---
    context: Fixture.Accounts
    reviewed: 2026-01-01
    surface: 000000000000
    functions: create_user/1 removed_fun/2
    ---

    # Accounts — Intent

    ## Purpose

    Own the account lifecycle.

    ## Accepted drift
    """

    updated = Intent.accept_drift(stale, group, ~D[2026-07-02])
    {:ok, card} = Intent.parse(updated)

    assert card.surface == group.surface_hash
    assert card.functions == group.functions
    assert card.reviewed == "2026-07-02"
    assert card.sections["Accepted drift"] =~ "2026-07-02: surface changed"
    assert card.sections["Accepted drift"] =~ "−removed_fun/2"
    # untouched sections survive
    assert card.sections["Purpose"] == "Own the account lifecycle."
  end
end
