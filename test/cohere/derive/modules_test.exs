defmodule Cohere.Derive.ModulesTest do
  use ExUnit.Case, async: true

  alias Cohere.Derive.Modules

  describe "classify/1" do
    test "functional classification, not name-based" do
      assert Modules.classify(Fixture.Accounts.User) == :schema
      assert Modules.classify(Fixture.Accounts.Profile) == :embedded_schema
      # Lives in the schema layer, is NOT a schema — the Cloak trap.
      assert Modules.classify(Fixture.Encrypted.Binary) == :ecto_type
      assert Modules.classify(Fixture.Repo) == :repo
      assert Modules.classify(FixtureWeb.Router) == :router
      assert Modules.classify(Fixture.Workers.SyncWorker) == :worker
      assert Modules.classify(Fixture.Accounts) == :module
      assert Modules.classify(String.Chars.Fixture.Accounts.User) == :protocol_impl
    end
  end

  describe "inventory/1" do
    setup do
      %{inventory: Modules.inventory(Cohere.Fixtures.project())}
    end

    test "groups the domain layer by top-level segment", %{inventory: inv} do
      names = Enum.map(inv.groups, & &1.name)
      assert names == ["Accounts", "Billing", "Encrypted", "Repo", "Workers"]
    end

    test "domain context owns schemas and a surface", %{inventory: inv} do
      accounts = Enum.find(inv.groups, &(&1.name == "Accounts"))

      assert accounts.kind == :domain
      assert accounts.context == Fixture.Accounts
      assert accounts.doc == "Account lifecycle: signup, membership, suspension."

      assert accounts.schemas == [
               Fixture.Accounts.Membership,
               Fixture.Accounts.Profile,
               Fixture.Accounts.User
             ]

      assert {:create_user, 1} in accounts.functions
      assert accounts.surface_hash
    end

    test "schema-less API module is a service context", %{inventory: inv} do
      billing = Enum.find(inv.groups, &(&1.name == "Billing"))
      assert billing.kind == :service
      assert billing.context == Fixture.Billing
    end

    test "module collections without a context module are passive", %{inventory: inv} do
      workers = Enum.find(inv.groups, &(&1.name == "Workers"))
      assert workers.kind == :passive
      assert workers.context == nil
      assert workers.workers == [Fixture.Workers.SyncWorker]

      encrypted = Enum.find(inv.groups, &(&1.name == "Encrypted"))
      assert encrypted.kind == :passive
      assert encrypted.others == [Fixture.Encrypted.Binary]
    end

    test "web modules are counted, routers extracted", %{inventory: inv} do
      assert inv.routers == [FixtureWeb.Router]
      assert inv.web[:router] == 1
      assert inv.web[:controller] == 1
    end

    test "protocol impls are excluded from groups", %{inventory: inv} do
      all_members =
        Enum.flat_map(inv.groups, fn g ->
          [g.context | g.schemas ++ g.workers ++ g.others]
        end)

      refute String.Chars.Fixture.Accounts.User in all_members
    end
  end
end
