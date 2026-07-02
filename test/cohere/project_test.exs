defmodule Cohere.ProjectTest do
  use ExUnit.Case, async: true

  alias Cohere.Project

  test "detects real capabilities and skips absent ones" do
    project = Cohere.Fixtures.project()

    # Ecto and Phoenix are real test deps; their versions resolve.
    assert is_binary(project.capabilities[:ecto])
    assert is_binary(project.capabilities[:phoenix])

    # The fake Oban.Worker behaviour is loadable, so oban is "present"
    # (duck-typed detection — exactly what probing should do).
    assert Map.has_key?(project.capabilities, :oban)

    refute Map.has_key?(project.capabilities, :boundary)
    refute Map.has_key?(project.capabilities, :ash)
  end

  test "derives namespace from app name and honors overrides" do
    project = Project.load(app: :cohere, modules: [])
    assert project.namespace == Cohere

    project = Cohere.Fixtures.project()
    assert project.namespace == Fixture
    assert project.web_namespace == FixtureWeb
  end

  test "detects the web namespace from module names" do
    project = Project.load(app: :cohere, modules: Cohere.Fixtures.modules(), namespace: Fixture)
    assert project.web_namespace == FixtureWeb
  end

  test "ignore list prunes modules" do
    project = Cohere.Fixtures.project(ignore: [Fixture.Repo])
    refute Fixture.Repo in project.modules
  end

  test "paths derive from the configured dir" do
    project = Cohere.Fixtures.project(dir: "tmp/coh")
    assert Project.map_path(project) == "tmp/coh/map.md"
    assert Project.intent_dir(project) == "tmp/coh/intent"
  end
end
