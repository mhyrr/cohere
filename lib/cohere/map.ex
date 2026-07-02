defmodule Cohere.Map do
  @moduledoc """
  The derived map: the actual shape of the system, assembled from reflection
  over the compiled application.

  The map is 100% derived and deterministic — same code in, same bytes out,
  no timestamps — so regenerating it in CI is free and diffing it is
  meaningful. It is the level-2 rung of the coherence ladder: truth that
  cannot lie because nobody authors it.
  """

  alias Cohere.Project
  alias Cohere.Derive.{Modules, Routes, Schemas, Workers}

  defstruct project: nil,
            groups: [],
            schemas: [],
            routers: [],
            jobs: %{workers: [], queues: [], crontab: %{}},
            web: %{},
            root: [],
            other: []

  @type t :: %__MODULE__{}

  @doc "Builds the full map for a project."
  @spec build(Project.t()) :: t()
  def build(%Project{} = project) do
    inventory = Modules.inventory(project)

    schema_modules = Enum.flat_map(inventory.groups, & &1.schemas)
    worker_modules = Enum.flat_map(inventory.groups, & &1.workers)

    %__MODULE__{
      project: project,
      groups: inventory.groups,
      schemas: Schemas.derive(schema_modules),
      routers: Routes.derive(inventory.routers),
      jobs: Workers.derive(worker_modules, project.app),
      web: inventory.web,
      root: inventory.root,
      other: inventory.other
    }
  end

  @doc "Builds and renders the map to markdown in one step."
  @spec render(Project.t()) :: String.t()
  def render(%Project{} = project) do
    project |> build() |> Cohere.Map.Renderer.render()
  end

  @doc "Finds a context group by name (`\"Deals\"`) or module (`MyApp.Deals`)."
  def fetch_group(%__MODULE__{groups: groups}, name) do
    target = to_string(name)

    Enum.find(groups, fn group ->
      group.name == target or
        (group.context != nil and inspect(group.context) == target) or
        String.downcase(group.name) == String.downcase(target)
    end)
  end
end
