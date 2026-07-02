defmodule Mix.Tasks.Cohere.Map do
  @shortdoc "Regenerates the derived system map"

  @moduledoc """
  Derives the system map from the compiled application and writes it to
  `cohere/map.md` (configurable via `config :cohere, dir: ...`).

      $ mix cohere.map

  The map is deterministic: same code in, same bytes out. Commit it; the
  diff on a PR *is* the ontology change.
  """

  use Mix.Task

  alias Cohere.{Map, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(_args) do
    project = Project.load()
    map = Map.build(project)
    rendered = Cohere.Map.Renderer.render(map)

    path = Project.map_path(project)
    File.mkdir_p!(Path.dirname(path))

    changed? = File.read(path) != {:ok, rendered}
    File.write!(path, rendered)

    contexts = Enum.count(map.groups, & &1.context)
    schemas = length(map.schemas)
    routes = map.routers |> Enum.map(fn {_r, routes} -> length(routes) end) |> Enum.sum()

    status = if changed?, do: "updated", else: "unchanged"

    Mix.shell().info(
      "#{path} #{status} — #{contexts} contexts, #{schemas} schemas, " <>
        "#{routes} routes, #{length(map.jobs.workers)} workers"
    )
  end
end
