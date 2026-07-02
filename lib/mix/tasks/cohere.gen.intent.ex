defmodule Mix.Tasks.Cohere.Gen.Intent do
  @shortdoc "Generates intent card skeletons for contexts"

  @moduledoc """
  Generates an intent card skeleton for each named context, bound to its
  current public surface (so a fresh card is born non-drifted).

      $ mix cohere.gen.intent deals billing
      $ mix cohere.gen.intent --all        # every context-ful group
      $ mix cohere.gen.intent deals --force  # overwrite an existing card

  Cards are the *authored* layer — the skeleton is scaffolding, not
  content. Fill in only what cannot be derived: purpose, invariants,
  decisions, non-goals. If a section has nothing durable to say, leave it
  empty rather than restating the code.
  """

  use Mix.Task

  alias Cohere.{Intent, Map, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, names} = OptionParser.parse!(args, strict: [all: :boolean, force: :boolean])

    project = Project.load()
    map = Map.build(project)

    groups =
      cond do
        opts[:all] ->
          Enum.filter(map.groups, & &1.context)

        names != [] ->
          Enum.map(names, fn name ->
            Map.fetch_group(map, name) ||
              Mix.raise(
                "unknown context #{inspect(name)} — known: " <>
                  Enum.map_join(Enum.filter(map.groups, & &1.context), ", ", & &1.name)
              )
          end)

        true ->
          Mix.raise("usage: mix cohere.gen.intent <context...> | --all")
      end

    dir = Project.intent_dir(project)
    File.mkdir_p!(dir)

    Enum.each(groups, fn group ->
      unless group.context do
        Mix.raise("#{group.name} has no context module — nothing to bind a card to")
      end

      path = Path.join(dir, Intent.filename(group))

      if File.exists?(path) and not (opts[:force] || false) do
        Mix.shell().info("#{path} exists — skipping (use --force to overwrite)")
      else
        File.write!(path, Intent.skeleton(group, Date.utc_today()))
        Mix.shell().info("created #{path}")
      end
    end)
  end
end
