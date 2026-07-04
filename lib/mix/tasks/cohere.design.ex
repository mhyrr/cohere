defmodule Mix.Tasks.Cohere.Design do
  @shortdoc "Starts a design: scaffolds a draft doc with its existing ground"

  @moduledoc """
  The start verb of the feature loop — and, with no arguments, the listing.

      $ mix cohere.design                                    # list designs + statuses
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

    case argv do
      [] -> list(Project.load())
      [slug] -> start(Project.load(), validate_slug!(slug), opts)
      _ -> Mix.raise("usage: mix cohere.design [<slug>] [--contexts deals,billing]")
    end
  end

  defp list(project) do
    case Design.load_all(project) do
      [] ->
        Mix.shell().info(
          "no designs yet — start one: mix cohere.design <slug> --contexts <contexts>"
        )

      docs ->
        width = docs |> Enum.map(&String.length(&1.slug)) |> Enum.max()

        lines =
          Enum.map(docs, fn doc ->
            "  #{String.pad_trailing(doc.slug, width)}  " <>
              "#{String.pad_trailing(to_string(doc.status), 10)}  #{doc.date}" <>
              supersedes_note(doc) <> flight_note(doc)
          end)

        drafts = Enum.count(docs, &(&1.status == :draft))

        summary =
          case drafts do
            0 -> "none in flight"
            n -> "#{n} in flight"
          end

        Mix.shell().info(
          Enum.join(
            ["#{Project.design_dir(project)} — #{length(docs)} design(s)", "" | lines],
            "\n"
          ) <>
            "\n\n#{summary}"
        )
    end
  end

  defp supersedes_note(%{supersedes: nil}), do: ""
  defp supersedes_note(%{supersedes: slug}), do: "  (supersedes #{slug})"

  defp flight_note(%{status: :draft, slug: slug}) do
    "  ← in flight; `mix cohere.complete #{slug}` when built"
  end

  defp flight_note(_doc), do: ""

  defp start(project, slug, opts) do
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
