defmodule Cohere.Docs do
  @moduledoc """
  Renders the cohere docs site: authored markdown in `docs_src/` becomes
  static HTML in `docs/`, alongside pages derived from the compiled tasks
  and the repo's own coherence artifacts.

  The site is built on the tool's own split — derived where possible
  (command reference from task moduledocs, the self page from the live
  map), authored where necessary (the narrative pages). The renderer
  covers only the constrained markdown subset the authored pages use;
  we author the input, so completeness is a non-goal — the same judgment
  as hand-parsed frontmatter over a YAML dependency.

  Rendering is deterministic: same sources in, same bytes out. Nothing
  here reads a clock, the network, or git state, so a CI rebuild plus
  `git diff --exit-code docs/` is a complete freshness gate.
  """

  alias Cohere.Markdown

  @tagline "A coherence layer for Elixir/Phoenix projects."

  # Loop verbs first, plumbing after; tasks not listed here sort in at the
  # end alphabetically, so a new task can't silently miss the reference.
  @task_order [
    Mix.Tasks.Cohere,
    Mix.Tasks.Cohere.Init,
    Mix.Tasks.Cohere.Design,
    Mix.Tasks.Cohere.Check,
    Mix.Tasks.Cohere.Complete,
    Mix.Tasks.Cohere.Map,
    Mix.Tasks.Cohere.Gen.Intent,
    Mix.Tasks.Cohere.Packet
  ]

  @doc """
  Builds the site.

  Options:

    * `:src` — source directory (default `"docs_src"`)
    * `:out` — output directory (default `"docs"`)
    * `:base_url` — absolute site root, used for links in `llms.txt`
  """
  def build(opts \\ []) do
    src = Keyword.get(opts, :src, "docs_src")
    out = Keyword.get(opts, :out, "docs")
    base_url = opts |> Keyword.get(:base_url, "") |> String.trim_trailing("/")

    pages = load_pages(Path.join(src, "pages")) ++ [reference_page(), self_page()]
    nav = Enum.map(pages, &{&1.slug, &1.title})
    layout = Path.join(src, "layout.html.eex")

    File.mkdir_p!(out)

    Enum.each(pages, fn page ->
      html =
        EEx.eval_file(layout,
          assigns: [
            title: page.title,
            slug: page.slug,
            description: page.description,
            kind: page.kind,
            nav: nav,
            content: render_markdown(page.body),
            version: version()
          ]
        )

      File.write!(Path.join(out, page.slug <> ".html"), html)
      File.write!(Path.join(out, page.slug <> ".md"), "# #{page.title}\n\n#{page.body}")
    end)

    File.write!(Path.join(out, "llms.txt"), llms_txt(pages, base_url))
    File.write!(Path.join(out, ".nojekyll"), "")
    copy_assets(src, out)
    :ok
  end

  # -- rendering ---------------------------------------------------------------

  @doc """
  Renders the constrained markdown subset to HTML: `#`–`####` headings
  (with slug ids), paragraphs, fenced and four-space-indented code blocks,
  inline code/bold/italic/links, flat lists, blockquotes, rules, and raw
  HTML passthrough for block-level tags.
  """
  def render_markdown(text) do
    text |> String.split("\n") |> blocks([]) |> Enum.reverse() |> Enum.join("\n")
  end

  defp blocks([], acc), do: acc
  defp blocks(["" | rest], acc), do: blocks(rest, acc)

  defp blocks(["```" <> lang | rest], acc) do
    {code, rest} = Enum.split_while(rest, &(&1 != "```"))
    rest = Enum.drop(rest, 1)
    class = if lang == "", do: "", else: ~s( class="lang-#{lang}")
    html = "<pre><code#{class}>#{escape(Enum.join(code, "\n"))}\n</code></pre>"
    blocks(rest, [html | acc])
  end

  defp blocks(["#### " <> text | rest], acc), do: blocks(rest, [heading(4, text) | acc])
  defp blocks(["### " <> text | rest], acc), do: blocks(rest, [heading(3, text) | acc])
  defp blocks(["## " <> text | rest], acc), do: blocks(rest, [heading(2, text) | acc])
  defp blocks(["# " <> text | rest], acc), do: blocks(rest, [heading(1, text) | acc])

  defp blocks([line | rest], acc) when line in ["---", "***"] do
    blocks(rest, ["<hr>" | acc])
  end

  defp blocks([">" <> _ | _] = lines, acc) do
    {quoted, rest} = Enum.split_while(lines, &String.starts_with?(&1, ">"))

    text =
      quoted
      |> Enum.map_join("\n", fn line -> line |> String.trim_leading(">") |> String.trim() end)
      |> inline()

    blocks(rest, ["<blockquote><p>#{text}</p></blockquote>" | acc])
  end

  defp blocks(["- " <> _ | _] = lines, acc) do
    {items, rest} = collect_items(lines, &String.starts_with?(&1, "- "))
    lis = Enum.map_join(items, "\n", fn "- " <> text -> "<li>#{inline(text)}</li>" end)
    blocks(rest, ["<ul>\n#{lis}\n</ul>" | acc])
  end

  defp blocks(["    " <> _ | _] = lines, acc) do
    {code, rest} = Enum.split_while(lines, &String.starts_with?(&1, "    "))
    text = Enum.map_join(code, "\n", fn "    " <> line -> line end)
    blocks(rest, ["<pre><code>#{escape(text)}\n</code></pre>" | acc])
  end

  defp blocks(["<" <> _ | _] = lines, acc) do
    {raw, rest} = Enum.split_while(lines, &(&1 != ""))
    blocks(rest, [Enum.join(raw, "\n") | acc])
  end

  defp blocks([line | rest] = lines, acc) do
    if ordered_item?(line) do
      {items, rest} = collect_items(lines, &ordered_item?/1)

      lis =
        Enum.map_join(items, "\n", fn item ->
          "<li>#{item |> String.replace(~r/^\d+\.\s+/, "") |> inline()}</li>"
        end)

      blocks(rest, ["<ol>\n#{lis}\n</ol>" | acc])
    else
      {para, rest} = Enum.split_while([line | rest], &paragraph_line?/1)
      blocks(rest, ["<p>#{para |> Enum.join("\n") |> inline()}</p>" | acc])
    end
  end

  defp ordered_item?(line), do: line =~ ~r/^\d+\.\s+/

  # A list item may continue on indented lines; fold them into the item so
  # authored pages can wrap naturally.
  defp collect_items(lines, item?) do
    {taken, rest} =
      Enum.split_while(lines, fn line ->
        item?.(line) or String.starts_with?(line, "  ")
      end)

    items =
      taken
      |> Enum.reduce([], fn line, acc ->
        if item?.(line) do
          [line | acc]
        else
          [hd(acc) <> "\n" <> String.trim(line) | tl(acc)]
        end
      end)
      |> Enum.reverse()

    {items, rest}
  end

  defp paragraph_line?(""), do: false

  defp paragraph_line?(line) do
    not (String.starts_with?(line, ["#", ">", "- ", "```", "    ", "<"]) or
           line in ["---", "***"] or ordered_item?(line))
  end

  defp heading(level, text) do
    id =
      text
      |> String.replace("`", "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    ~s(<h#{level} id="#{id}">#{inline(text)}</h#{level}>)
  end

  defp inline(text) do
    ~r/`[^`]+`/
    |> Regex.split(text, include_captures: true)
    |> Enum.map_join(fn segment ->
      case Regex.run(~r/^`(.+)`$/s, segment) do
        [_, code] -> "<code>#{escape(code)}</code>"
        nil -> segment |> escape() |> format()
      end
    end)
  end

  defp format(text) do
    text
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, ~S(<a href="\2">\1</a>))
    |> String.replace(~r/\*\*([^*]+)\*\*/, ~S(<strong>\1</strong>))
    |> String.replace(~r/\*([^*]+)\*/, ~S(<em>\1</em>))
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  # -- authored pages -----------------------------------------------------------

  defp load_pages(dir) do
    dir
    |> File.ls!()
    |> Enum.sort()
    |> Enum.filter(&String.ends_with?(&1, ".md"))
    |> Enum.map(fn file ->
      {:ok, front, body} = dir |> Path.join(file) |> File.read!() |> Markdown.split_frontmatter()

      %{
        slug: Path.rootname(file),
        title: front["title"] || Path.rootname(file),
        description: front["description"] || "",
        nav: String.to_integer(front["nav"] || "99"),
        kind: "authored",
        body: body
      }
    end)
    |> Enum.sort_by(& &1.nav)
  end

  # -- derived pages ------------------------------------------------------------

  defp reference_page do
    entries = Enum.map_join(task_modules(), "\n\n", &task_entry/1)

    body = """
    #{stamp("task moduledocs, via reflection")}

    Every entry below is read from the compiled task's own `@shortdoc`
    and `@moduledoc` — the reference cannot drift from the tool, because
    it is the tool describing itself.

    #{entries}
    """

    %{
      slug: "reference",
      title: "Reference",
      description: "Every mix task, derived from its own moduledoc.",
      nav: 98,
      kind: "derived",
      body: body
    }
  end

  defp task_modules do
    {:ok, modules} = :application.get_key(:cohere, :modules)
    tasks = Enum.filter(modules, &String.starts_with?(Atom.to_string(&1), "Elixir.Mix.Tasks."))
    Enum.filter(@task_order, &(&1 in tasks)) ++ Enum.sort(tasks -- @task_order)
  end

  defp task_entry(module) do
    "## mix #{Mix.Task.task_name(module)}\n\n*#{Mix.Task.shortdoc(module)}*\n\n#{moduledoc(module)}"
  end

  defp moduledoc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} -> doc
      _ -> ""
    end
  end

  defp self_page do
    map = "cohere/map.md" |> File.read!() |> String.replace(~r/^#/m, "##")
    {:ok, _front, card} = "cohere/intent/map.md" |> File.read!() |> Markdown.split_frontmatter()

    body = """
    Cohere runs on itself. Everything on this page is lifted from this
    repository's own `cohere/` directory — the same artifacts the CI gate
    checks on every push.

    #{stamp("cohere/map.md — the committed map of this repo")}

    <section class="derived-doc">

    #{map}

    </section>

    ## The authored half: the map's own intent card

    The map above is derived; the card below is authored. It binds to the
    `Cohere.Map` context by surface hash, so `mix cohere.check` fails the
    build the moment the code moves out from under it.

    <section class="authored-doc">

    #{card}

    </section>
    """

    %{
      slug: "self",
      title: "Cohere on cohere",
      description: "The repo's live map and an intent card, as shipped.",
      nav: 99,
      kind: "derived",
      body: body
    }
  end

  defp stamp(source) do
    ~s(<div class="stamp">derived · #{source} · cohere #{version()}</div>)
  end

  defp version do
    :cohere |> Application.spec(:vsn) |> to_string()
  end

  # -- site chrome ---------------------------------------------------------------

  defp llms_txt(pages, base_url) do
    entries =
      Enum.map_join(pages, "\n", fn page ->
        "- [#{page.title}](#{base_url}/#{page.slug}.md): #{page.description}"
      end)

    "# cohere\n\n> #{@tagline}\n\n#{entries}\n"
  end

  defp copy_assets(src, out) do
    assets = Path.join(src, "assets")
    if File.dir?(assets), do: File.cp_r!(assets, Path.join(out, "assets"))
  end
end
