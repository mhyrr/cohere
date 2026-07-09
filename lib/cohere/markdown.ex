defmodule Cohere.Markdown do
  @moduledoc """
  Frontmatter and section mechanics shared by every authored artifact —
  intent cards and design docs.

  Frontmatter is a hand-parsed key/value block, deliberately not YAML: the
  keys cohere manages are flat strings, and a YAML parser would be a
  dependency consumers inherit for no expressive gain.
  """

  @doc """
  Splits a document into `{:ok, frontmatter_map, body}`, where the
  frontmatter is the leading `---` block parsed as `key: value` lines.
  """
  @spec split_frontmatter(String.t()) ::
          {:ok, %{String.t() => String.t()}, String.t()} | {:error, :no_frontmatter}
  def split_frontmatter(text) do
    case String.split(text, ~r/^---\s*$/m, parts: 3) do
      ["", front, body] -> {:ok, parse_front(front), String.trim_leading(body, "\n")}
      _ -> {:error, :no_frontmatter}
    end
  end

  defp parse_front(front) do
    front
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> [{String.trim(key), String.trim(value)}]
        _ -> []
      end
    end)
    |> Map.new()
  end

  @doc """
  Rewrites the frontmatter block, emitting `keys` in order with values from
  `front`. Keys whose value is nil or empty are dropped.
  """
  def replace_frontmatter(text, keys, front) do
    {:ok, _old, body} = split_frontmatter(text)

    lines =
      keys
      |> Enum.reject(fn key -> front[key] in [nil, ""] end)
      |> Enum.map_join("\n", fn key -> "#{key}: #{front[key]}" end)

    "---\n#{lines}\n---\n\n#{body}"
  end

  @doc ~S(Parses `## `-delimited sections into a `%{"Heading" => content}` map.)
  def sections(body) do
    body
    |> String.split(~r/^## /m)
    |> Enum.drop(1)
    |> Map.new(fn chunk ->
      case String.split(chunk, "\n", parts: 2) do
        [heading, content] -> {String.trim(heading), String.trim(content)}
        [heading] -> {String.trim(heading), ""}
      end
    end)
  end

  @doc "Appends a line to the named `## ` section, creating the section at the end if absent."
  def append_to_section(text, section, line) do
    heading = "## #{section}"
    # Anchored to line starts: prose mentioning "## Accepted drift" in
    # backticks must not count as the heading (found when INV-DRI-003's
    # own wording swallowed an annotation).
    heading_re = ~r/^#{Regex.escape(heading)}[ \t]*$/m

    case Regex.split(heading_re, text, parts: 2) do
      [before, rest] ->
        # Insert after the heading block, before the next heading (or at end).
        case String.split(rest, ~r/^## /m, parts: 2) do
          [section_body, next] ->
            before <>
              heading <>
              String.trim_trailing(section_body) <>
              "\n#{line}\n\n## " <> next

          [section_body] ->
            before <> heading <> String.trim_trailing(section_body) <> "\n#{line}\n"
        end

      [_no_heading] ->
        String.trim_trailing(text) <> "\n\n#{heading}\n\n#{line}\n"
    end
  end

  @doc """
  Backticked, fully-qualified code references in markdown text:
  `[{module_string, function_name | nil, arity | nil}]`, deduped in order.
  HTML comments are stripped first — a ref in a skeleton prompt is an
  example, not a claim.
  """
  def code_refs(text) do
    ~r/`([A-Z][A-Za-z0-9_.]*)(?:\.([a-z_][A-Za-z0-9_?!]*)\/(\d+))?`/
    |> Regex.scan(String.replace(text, ~r/<!--.*?-->/s, ""))
    |> Enum.flat_map(fn
      [_, module] -> [{module, nil, nil}]
      [_, module, fun, arity] -> [{module, fun, String.to_integer(arity)}]
    end)
    |> Enum.uniq()
  end

  @doc """
  Whether a `code_refs/1` tuple resolves in the compiled app: the module
  loads, and the function (when given) is exported at that arity.
  """
  def ref_exists?({module_name, fun, arity}) do
    module = Module.concat([module_name])

    cond do
      not Code.ensure_loaded?(module) -> false
      fun && not function_exported?(module, String.to_atom(fun), arity) -> false
      true -> true
    end
  end
end
