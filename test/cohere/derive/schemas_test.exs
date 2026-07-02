defmodule Cohere.Derive.SchemasTest do
  use ExUnit.Case, async: true

  alias Cohere.Derive.Schemas

  test "describes a schema: source, pk, fields with real types" do
    schema = Schemas.describe(Fixture.Accounts.User)

    assert schema.source == "users"
    assert schema.embedded? == false
    assert schema.primary_key == [:id]

    types = Map.new(schema.fields, &{&1.name, &1.type})
    assert types[:email] == "string"
    assert types[:status] == "enum(active|suspended)"
    assert types[:tags] == "[string]"

    assert Enum.find(schema.fields, &(&1.name == :id)).primary_key?
  end

  test "records links with name, target, and real foreign key" do
    schema = Schemas.describe(Fixture.Accounts.User)

    # assoc name ≠ target module ≠ FK — all three must be captured
    assert %{
             kind: :belongs_to,
             name: :reviewed_by,
             related: Fixture.Accounts.User,
             key: :reviewed_by_user_id
           } in schema.assocs

    assert %{
             kind: :has_many,
             name: :memberships,
             related: Fixture.Accounts.Membership,
             key: :user_id
           } in schema.assocs
  end

  test "embedded schemas are marked and have no source" do
    schema = Schemas.describe(Fixture.Accounts.Profile)
    assert schema.embedded?
    assert schema.source == nil
  end

  test "embeds are links, not fields" do
    schema = Schemas.describe(Fixture.Accounts.User)

    refute Enum.any?(schema.fields, &(&1.name == :profile))

    assert schema.embeds == [
             %{name: :profile, cardinality: :one, related: Fixture.Accounts.Profile}
           ]
  end

  test "non-schema modules describe to nil" do
    assert Schemas.describe(Fixture.Encrypted.Binary) == nil
    assert Schemas.describe(Fixture.Billing) == nil
  end

  test "derive sorts by module name and drops non-schemas" do
    result = Schemas.derive([Fixture.Accounts.User, Fixture.Billing, Fixture.Accounts.Membership])
    assert Enum.map(result, & &1.module) == [Fixture.Accounts.Membership, Fixture.Accounts.User]
  end
end
