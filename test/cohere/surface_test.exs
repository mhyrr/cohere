defmodule Cohere.SurfaceTest do
  use ExUnit.Case, async: true

  alias Cohere.Surface

  test "lists sorted public functions, filtering generated ones" do
    functions = Surface.functions(Fixture.Accounts)

    assert functions == [
             {:create_user, 0},
             {:create_user, 1},
             {:get_user!, 1},
             {:list_users, 0},
             {:suspend_user, 1}
           ]

    refute {:child_spec, 1} in functions
  end

  test "schema modules expose no authored surface noise from __schema__" do
    refute Enum.any?(Surface.functions(Fixture.Accounts.User), fn {name, _} ->
             name |> to_string() |> String.starts_with?("__")
           end)
  end

  test "to_line/from_line roundtrip" do
    functions = Surface.functions(Fixture.Accounts)
    assert functions |> Surface.to_line() |> Surface.from_line() == functions
  end

  test "hash is stable and surface-sensitive" do
    functions = Surface.functions(Fixture.Accounts)

    assert Surface.hash(functions) == Surface.hash(functions)
    assert String.length(Surface.hash(functions)) == 12
    refute Surface.hash(functions) == Surface.hash(tl(functions))
  end
end
