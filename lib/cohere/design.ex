defmodule Cohere.Design do
  @moduledoc """
  Design docs: the authored artifact of the feature loop.

  A design doc records the conversation that shapes a change — problem,
  existing ground, shape, promised surface, decisions with their rejected
  alternatives. Docs live in `cohere/design/*.md`, are born `draft` by
  `mix cohere.design`, and are flipped to `accepted` by
  `mix cohere.complete` once every promised ref exists in the compiled
  app. Accepted designs are immutable history: supersede them, never edit
  them.

  Designs are deliberately weaker-bound than intent cards. A card is a
  living constraint set, hash-bound to a surface, and drift on it fails
  the build. A design is a dated record; drift against it warns and never
  fails (DEC-FEA-002 in `cohere/design/feature-loop.md`).
  """

  alias Cohere.{Intent, Map, Markdown, Project, Surface}

  defmodule Doc do
    @moduledoc false
    defstruct path: nil,
              slug: nil,
              status: :draft,
              date: nil,
              contexts: [],
              supersedes: nil,
              body: "",
              sections: %{}

    @type t :: %__MODULE__{}
  end

  @statuses %{"draft" => :draft, "accepted" => :accepted, "superseded" => :superseded}
  @promised_heading "Promised surface"
  @frontmatter_keys ~w(design status date contexts supersedes)

  @doc "Loads every design doc in the project's design directory."
  @spec load_all(Project.t()) :: [Doc.t()]
  def load_all(%Project{} = project) do
    dir = Project.design_dir(project)

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.sort()
        |> Enum.flat_map(fn file ->
          path = Path.join(dir, file)

          case parse(File.read!(path), path) do
            {:ok, doc} -> [doc]
            {:error, _} -> []
          end
        end)

      {:error, _} ->
        []
    end
  end

  @doc "Parses design doc text. Returns `{:ok, %Doc{}}` or `{:error, reason}`."
  @spec parse(String.t(), String.t() | nil) :: {:ok, Doc.t()} | {:error, term()}
  def parse(text, path \\ nil) do
    with {:ok, front, body} <- Markdown.split_frontmatter(text),
         {:ok, slug} <- fetch_slug(front),
         {:ok, status} <- fetch_status(front) do
      {:ok,
       %Doc{
         path: path,
         slug: slug,
         status: status,
         date: front["date"],
         contexts: split_contexts(front["contexts"]),
         supersedes: presence(front["supersedes"]),
         body: body,
         sections: Markdown.sections(body)
       }}
    end
  end

  @doc "Conventional design doc filename for a slug."
  def filename(slug), do: slug <> ".md"

  @doc """
  Generates a draft design doc skeleton.

  Options: `:contexts` (anchored context names for the frontmatter) and
  `:ground` (pre-rendered Existing ground body from `ground/2`).
  """
  def skeleton(slug, date, opts \\ []) do
    contexts = opts[:contexts] || []
    prefix = id_prefix(slug)

    """
    ---
    design: #{slug}
    status: draft
    date: #{date}
    contexts: #{Enum.join(contexts, ", ")}
    ---

    # #{title(slug)} — Design

    ## Problem

    <!-- Why this work exists. What breaks, or is missing, without it? -->

    ## Existing ground

    > Snapshot assembled #{date} from the map and intent cards. A dated
    > record of the constraints this design is shaped against — the map
    > and cards remain canonical.

    #{ground_or_note(opts[:ground])}

    ## Shape

    <!-- The design itself: moving parts, data flow, what changes and what
         deliberately doesn't. -->

    ## Promised surface

    <!-- Backticked refs this design commits to delivering, e.g.
         `MyApp.Deals.reverse_deal/1`. Exempt from dead-ref checks while
         draft; `mix cohere.complete #{slug}` fails until every one exists. -->

    ## Decisions

    <!-- Dated, with the rejected alternative. Example:
    - DEC-#{prefix}-001 (#{date}): chose X because Y. Rejected: Z.
    -->

    ## Open questions

    ## Status log
    """
  end

  @doc """
  Renders the Existing ground for a set of context names: each anchored
  context's current API from the map, plus the invariants and decisions
  from its intent card when one exists. Names that resolve to nothing are
  rendered as proposed — a design may introduce the context it anchors to.
  """
  def ground(%Project{} = project, context_names) do
    map = Map.build(project)
    cards = Intent.load_all(project)

    Enum.map_join(context_names, "\n", fn name ->
      case Map.fetch_group(map, name) do
        nil ->
          "### #{name} — proposed\n\nNot in the map yet; this design introduces it.\n"

        group ->
          card = Enum.find(cards, &(&1.context == group.context))

          [group_heading(group), api_line(group), constraints(card)]
          |> Enum.reject(&is_nil/1)
          |> Enum.join("\n")
          |> Kernel.<>("\n")
      end
    end)
  end

  @doc """
  The refs promised in the `## Promised surface` section, parsed without
  a namespace filter — a promise is explicit, so anything promised is
  checked, mix tasks included.
  """
  def promised_refs(%Doc{sections: sections}) do
    Markdown.code_refs(sections[@promised_heading] || "")
  end

  @doc "Promised refs that do not (yet) resolve in the compiled app."
  def unmet_promises(%Doc{} = doc) do
    doc
    |> promised_refs()
    |> Enum.reject(&Markdown.ref_exists?/1)
  end

  @doc """
  Flips a draft's status to accepted and appends a dated Status log line.
  The `date:` frontmatter keeps the design date; the log carries the
  acceptance date.
  """
  def accept(text, date) do
    {:ok, front, _body} = Markdown.split_frontmatter(text)

    text
    |> Markdown.replace_frontmatter(
      @frontmatter_keys,
      Elixir.Map.put(front, "status", "accepted")
    )
    |> Markdown.append_to_section(
      "Status log",
      "- #{date}: accepted — promised surface verified"
    )
  end

  @doc """
  Soft findings for a design doc — never build-failing (DEC-FEA-002):

    * `{:anchor_missing, name}` — an anchored context isn't in the map
      (fine for a draft that introduces it; `mix cohere.complete` verifies)
    * `{:broken_ref, ref}` — a namespaced ref outside Promised surface
      that doesn't resolve
  """
  def issues(%Doc{} = doc, %Map{} = map, %Project{} = project) do
    anchor_issues(doc, map) ++ ref_issues(doc, project)
  end

  defp anchor_issues(doc, map) do
    doc.contexts
    |> Enum.reject(&Map.fetch_group(map, &1))
    |> Enum.map(&{:anchor_missing, &1})
  end

  defp ref_issues(doc, project) do
    prefix = inspect(project.namespace) <> "."

    doc.sections
    |> Elixir.Map.drop([@promised_heading])
    |> Elixir.Map.values()
    |> Enum.join("\n")
    |> Markdown.code_refs()
    |> Enum.filter(fn {module, _, _} ->
      String.starts_with?(module, prefix) or module == inspect(project.namespace)
    end)
    |> Enum.reject(&Markdown.ref_exists?/1)
    |> Enum.map(fn
      {module, nil, nil} -> {:broken_ref, module}
      {module, fun, arity} -> {:broken_ref, "#{module}.#{fun}/#{arity}"}
    end)
  end

  # -- skeleton helpers -------------------------------------------------------

  defp ground_or_note(nil), do: ground_or_note("")

  defp ground_or_note(ground) do
    case String.trim(ground) do
      "" ->
        "<!-- No contexts anchored yet. Add names to the `contexts:` line and\n" <>
          "     re-run `mix cohere.design` on a fresh slug, or paste the relevant\n" <>
          "     constraints here by hand. -->"

      trimmed ->
        trimmed
    end
  end

  defp group_heading(%{context: nil} = group), do: "### #{group.name} — #{group.kind}"
  defp group_heading(group), do: "### #{inspect(group.context)} — #{group.kind}"

  defp api_line(%{functions: []}), do: nil

  defp api_line(group) do
    "\n**API** (#{length(group.functions)}): #{Surface.to_line(group.functions)}"
  end

  defp constraints(nil) do
    "\n_No intent card for this context._"
  end

  defp constraints(card) do
    quoted =
      ["Invariants", "Decisions"]
      |> Enum.flat_map(fn heading ->
        case meaningful(card.sections[heading]) do
          nil -> []
          content -> ["\n#{heading} (from `#{card.path}`):\n#{content}"]
        end
      end)

    case quoted do
      [] -> "\n_Intent card `#{card.path}` has no invariants or decisions yet._"
      quoted -> Enum.join(quoted, "\n")
    end
  end

  # Section content that survives comment-stripping; skeleton prompts don't count.
  defp meaningful(nil), do: nil

  defp meaningful(content) do
    case content |> String.replace(~r/<!--.*?-->/s, "") |> String.trim() do
      "" -> nil
      stripped -> stripped
    end
  end

  # -- parsing helpers --------------------------------------------------------

  defp fetch_slug(front) do
    case presence(front["design"]) do
      nil -> {:error, :missing_slug}
      slug -> {:ok, slug}
    end
  end

  defp fetch_status(front) do
    case Elixir.Map.fetch(@statuses, front["status"] || "") do
      {:ok, status} -> {:ok, status}
      :error -> {:error, {:bad_status, front["status"]}}
    end
  end

  defp split_contexts(nil), do: []

  defp split_contexts(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp presence(nil), do: nil
  defp presence(value), do: if(String.trim(value) == "", do: nil, else: String.trim(value))

  defp title(slug) do
    slug
    |> String.split(~r/[-_]/)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp id_prefix(slug) do
    cleaned = slug |> String.replace(~r/[^A-Za-z]/, "") |> String.upcase()
    binary_part(cleaned, 0, min(3, byte_size(cleaned)))
  end
end
