defmodule Cohere.Intent do
  @moduledoc """
  Loads, parses, generates, and updates intent cards.

  Cards are markdown files with a small machine-managed frontmatter block
  (parsed by hand — no YAML dependency) and typed `##` sections. Humans and
  agents edit the sections; cohere manages the frontmatter.
  """

  alias Cohere.{Intent.Card, Markdown, Project, Surface}

  @doc "Loads every card in the project's intent directory."
  @spec load_all(Project.t()) :: [Card.t()]
  def load_all(%Project{} = project) do
    dir = Project.intent_dir(project)

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.sort()
        |> Enum.flat_map(fn file ->
          path = Path.join(dir, file)

          case parse(File.read!(path), path) do
            {:ok, card} -> [card]
            {:error, _} -> []
          end
        end)

      {:error, _} ->
        []
    end
  end

  @doc "Parses card text. Returns `{:ok, %Card{}}` or `{:error, reason}`."
  @spec parse(String.t(), String.t() | nil) :: {:ok, Card.t()} | {:error, term()}
  def parse(text, path \\ nil) do
    with {:ok, front, body} <- Markdown.split_frontmatter(text),
         {:ok, context} <- fetch_context(front) do
      {:ok,
       %Card{
         path: path,
         context: context,
         reviewed: front["reviewed"],
         surface: front["surface"],
         functions: Surface.from_line(front["functions"] || ""),
         body: body,
         sections: Markdown.sections(body)
       }}
    end
  end

  @doc """
  Generates a skeleton card for a context group, bound to its current
  surface so a fresh card is born non-drifted.
  """
  def skeleton(group, date) do
    prefix = id_prefix(group.name)

    """
    ---
    context: #{inspect(group.context)}
    reviewed: #{date}
    surface: #{group.surface_hash}
    functions: #{Surface.to_line(group.functions)}
    ---

    # #{group.name} — Intent

    ## Purpose

    <!-- One paragraph: why this context exists. What business capability does it own? -->

    ## Invariants

    <!-- Things that must stay true, one per line, with stable IDs. Example:
    - INV-#{prefix}-001: money amounts are integer cents, never floats.
    -->

    ## Decisions

    <!-- Dated, with the rejected alternative. Example:
    - DEC-#{prefix}-001 (#{date}): soft-delete, not hard-delete, because audit
      history must survive. Rejected: hard-delete with archive table.
    -->

    ## Non-goals

    <!-- What this context deliberately does not do, and where that lives instead. -->

    ## Open questions

    ## Accepted drift
    """
  end

  @doc """
  Rebinds a card's frontmatter to a new surface and appends an accepted-drift
  annotation. `opts[:by]` names who judged, in the annotation — attribution
  lives in event traces only, never frontmatter (DEC-AGE-004 in
  `cohere/design/agent-surfaces.md`). Returns the updated card text.
  """
  def accept_drift(text, group, date, opts \\ []) do
    {:ok, card} = parse(text)

    added = group.functions -- card.functions
    removed = card.functions -- group.functions

    delta =
      Enum.map_join(added, " ", fn {f, a} -> "+#{f}/#{a}" end) <>
        " " <> Enum.map_join(removed, " ", fn {f, a} -> "−#{f}/#{a}" end)

    annotation =
      "- #{date}: surface changed (#{String.trim(delta)}) — " <>
        "accepted#{attribution(opts[:by])}"

    text
    |> Markdown.replace_frontmatter(~w(context reviewed surface functions), %{
      "context" => inspect(group.context),
      "reviewed" => to_string(date),
      "surface" => group.surface_hash,
      "functions" => Surface.to_line(group.functions)
    })
    |> Markdown.append_to_section("Accepted drift", annotation)
  end

  defp attribution(nil), do: ""
  defp attribution(by), do: " (#{by})"

  @doc "Conventional card filename for a context group."
  def filename(group), do: Macro.underscore(group.name) <> ".md"

  @doc """
  Fully-qualified module references in the card body (backticked, inside the
  given namespace) — the checkable claims a card makes about code.

  Returns `[{module_string, function_name | nil, arity | nil}]`.
  """
  def refs(%Card{body: body}, namespace) do
    prefix = inspect(namespace) <> "."

    body
    |> Markdown.code_refs()
    |> Enum.filter(fn {module, _, _} ->
      String.starts_with?(module, prefix) or module == inspect(namespace)
    end)
  end

  defp fetch_context(front) do
    case front["context"] do
      nil -> {:error, :missing_context}
      name -> {:ok, Module.concat([name])}
    end
  end

  defp id_prefix(name) do
    name
    |> String.replace(~r/[^A-Za-z]/, "")
    |> String.upcase()
    |> binary_part(0, min(3, byte_size(name)))
  end
end
