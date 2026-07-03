defmodule Mix.Tasks.Cohere.Design do
  @shortdoc "Starts a design: scaffolds a draft doc with its existing ground"

  @moduledoc """
  The start verb of the feature loop.

      $ mix cohere.design deal-reversals --contexts deals,billing

  Scaffolds `cohere/design/deal-reversals.md` (status: draft) and
  assembles its Existing ground: for each anchored context, the current
  API from the map plus the invariants and decisions from its intent
  card — the constraints the design should be shaped against, delivered
  onto the page where the designing happens.

  Anchoring a context that doesn't exist yet is fine — the design may be
  the thing that introduces it; `mix cohere.complete` verifies it landed.

  Iterate with `mix cohere.check`; land with `mix cohere.complete <slug>`.
  """

  use Mix.Task

  alias Cohere.{Design, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, argv} = OptionParser.parse!(args, strict: [contexts: :string])

    slug =
      case argv do
        [slug] -> validate_slug!(slug)
        _ -> Mix.raise("usage: mix cohere.design <slug> [--contexts deals,billing]")
      end

    project = Project.load()
    dir = Project.design_dir(project)
    path = Path.join(dir, Design.filename(slug))

    if File.exists?(path) do
      Mix.raise(
        "#{path} already exists — designs are records; supersede with a new slug " <>
          "(`supersedes: #{slug}` in its frontmatter) instead of overwriting"
      )
    end

    contexts =
      (opts[:contexts] || "")
      |> String.split(",", trim: true)
      |> Enum.map(&String.trim/1)

    ground = Design.ground(project, contexts)

    File.mkdir_p!(dir)
    File.write!(path, Design.skeleton(slug, Date.utc_today(), contexts: contexts, ground: ground))

    Mix.shell().info("""
    created #{path} (draft)

    The loop from here:

      1. Design in the doc — shape, decisions with rejected alternatives,
         promised surface. The Existing ground section carries what already
         holds; design against it.
      2. mix cohere.check       — anytime; fix what it lists, repeat
      3. mix cohere.complete #{slug}   — when the build is in and check is quiet
    """)
  end

  defp validate_slug!(slug) do
    if slug =~ ~r/^[a-z0-9][a-z0-9-]*$/ do
      slug
    else
      Mix.raise("slug must be kebab-case ([a-z0-9-]), got: #{inspect(slug)}")
    end
  end
end
