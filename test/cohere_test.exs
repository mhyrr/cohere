defmodule CohereTest do
  use ExUnit.Case, async: true

  test "version is the mix project version" do
    assert Cohere.version() == Mix.Project.config()[:version]
  end
end
