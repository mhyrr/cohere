defmodule Mix.Tasks.Cohere.Design do
  @shortdoc "Starts a design: scaffolds a draft doc with its existing ground"

  @moduledoc """
  The start verb of the feature loop — and, with no arguments, the listing.

      $ mix cohere.design                                    # list designs + statuses
      $ mix cohere.design deal-reversals --contexts deals,billing
      $ mix cohere.design deal-reversals                     # contexts from the branch diff
      $ mix cohere.design deal-reversals --base develop      # …diffed against a given ref

  Scaffolds `cohere/design/deal-reversals.md` (status: draft) and
  assembles its Existing ground: for each anchored context, the current
  API from the map plus the invariants and decisions from its intent
  card — the constraints the design should be shaped against, delivered
  onto the page where the designing happens.

  With `--contexts` omitted, the anchors are inferred from the branch
  diff, the way `mix cohere.packet --diff` maps changed files to the
  contexts that own them. Design-first stays the primary path — the flag
  is explicit intent; inference serves the retrofit, where the change is
  underway before anyone admits it deserved a design.

  Anchoring a context that doesn't exist yet is fine — the design may be
  the thing that introduces it; `mix cohere.complete` verifies it landed.

  Iterate with `mix cohere.check`; land with `mix cohere.complete <slug>`.
  """

  use Mix.Task

  alias Cohere.{Design, Map, Packet, Project}

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, argv} = OptionParser.parse!(args, strict: [contexts: :string, base: :string])

    case argv do
      [] -> list(Project.load())
      [slug] -> start(Project.load(), validate_slug!(slug), opts)
      _ -> Mix.raise("usage: mix cohere.design [<slug>] [--contexts deals,billing] [--base REF]")
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

  # Same file→context resolution as `mix cohere.packet --diff` (DEC-AGE-005):
  # one matcher in the codebase, `Cohere.Packet.contexts_for_files/3`.
  defp infer_contexts(project, base) do
    files =
      case Project.changed_files(base) do
        {:ok, files} -> files
        {:error, message} -> Mix.raise(message <> " — or name anchors: --contexts <ctx>")
      end

    map = Map.build(project)
    report = Packet.contexts_for_files(map, Project.source_index(project), files)

    case report.contexts do
      [] ->
        Mix.raise(
          "no changed file mapped to a known context (#{length(files)} changed) — " <>
            "name the anchors: mix cohere.design <slug> --contexts <ctx>"
        )

      contexts ->
        contexts
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
      case opts[:contexts] do
        nil ->
          inferred = infer_contexts(project, opts[:base] || "main")
          Mix.shell().info("contexts inferred from branch diff: #{Enum.join(inferred, ", ")}")
          inferred

        given ->
          given
          |> String.split(",", trim: true)
          |> Enum.map(&String.trim/1)
      end

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
