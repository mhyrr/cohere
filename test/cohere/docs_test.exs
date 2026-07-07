defmodule Cohere.DocsTest do
  use ExUnit.Case, async: true

  alias Cohere.Docs

  @moduletag :tmp_dir

  # -- render_markdown: the constrained subset --------------------------------

  test "headings h1–h4 with slug ids" do
    assert Docs.render_markdown("# The Map") =~ ~s(<h1 id="the-map">The Map</h1>)
    assert Docs.render_markdown("## Intent cards") =~ ~s(<h2 id="intent-cards">)
    assert Docs.render_markdown("### A. B c") =~ ~s(<h3 id="a-b-c">)
    assert Docs.render_markdown("#### Deep") =~ ~s(<h4 id="deep">)
  end

  test "heading slugs strip inline code backticks" do
    assert Docs.render_markdown("## The `mix cohere.check` gate") =~
             ~s(<h2 id="the-mix-cohere-check-gate">)
  end

  test "paragraphs join contiguous lines" do
    html = Docs.render_markdown("one\ntwo\n\nthree")
    assert html =~ "<p>one\ntwo</p>"
    assert html =~ "<p>three</p>"
  end

  test "inline code, bold, italic, links" do
    html = Docs.render_markdown("call `build/1` on **the** *map* — see [docs](loop.html)")
    assert html =~ "<code>build/1</code>"
    assert html =~ "<strong>the</strong>"
    assert html =~ "<em>map</em>"
    assert html =~ ~s(<a href="loop.html">docs</a>)
  end

  test "no formatting applies inside code spans" do
    html = Docs.render_markdown("run `mix a --flag **not bold**` now")
    assert html =~ "<code>mix a --flag **not bold**</code>"
    refute html =~ "<strong>"
  end

  test "html is escaped in text and code" do
    html = Docs.render_markdown("a <b> & `x < y`")
    assert html =~ "a &lt;b&gt; &amp;"
    assert html =~ "<code>x &lt; y</code>"
  end

  test "fenced code blocks keep language and escape contents" do
    html = Docs.render_markdown("```elixir\n1 < 2 && true\n```")
    assert html =~ ~s(<pre><code class="lang-elixir">1 &lt; 2 &amp;&amp; true\n</code></pre>)
  end

  test "four-space indented lines become code blocks (moduledoc style)" do
    html = Docs.render_markdown("Usage:\n\n    $ mix cohere.check\n    exit 1 on drift\n\nDone.")
    assert html =~ "<pre><code>$ mix cohere.check\nexit 1 on drift\n</code></pre>"
    assert html =~ "<p>Done.</p>"
  end

  test "unordered and ordered lists" do
    html = Docs.render_markdown("- one\n- two\n\n1. first\n2. second")
    assert html =~ "<ul>\n<li>one</li>\n<li>two</li>\n</ul>"
    assert html =~ "<ol>\n<li>first</li>\n<li>second</li>\n</ol>"
  end

  test "indented continuation lines fold into their list item" do
    html =
      Docs.render_markdown("- **one** — a thing\n  that wraps\n- two\n\n1. first\n   also wraps")

    assert html =~ "<li><strong>one</strong> — a thing\nthat wraps</li>"
    assert html =~ "<li>two</li>"
    assert html =~ "<li>first\nalso wraps</li>"
    refute html =~ "<p>that wraps</p>"
  end

  test "blockquotes render with inline formatting" do
    html = Docs.render_markdown("> a project is *coherent* to the degree\n> that it can act")
    assert html =~ "<blockquote>"
    assert html =~ "<em>coherent</em>"
  end

  test "horizontal rules" do
    assert Docs.render_markdown("---") =~ "<hr>"
  end

  test "raw html blocks pass through untouched" do
    raw = ~s(<div class="stamp">derived · mix cohere.map</div>)
    assert Docs.render_markdown(raw <> "\n\nafter") =~ raw
  end

  # -- build/1: the site -------------------------------------------------------

  defp scaffold_src!(tmp) do
    src = Path.join(tmp, "docs_src")
    File.mkdir_p!(Path.join(src, "pages"))
    File.mkdir_p!(Path.join(src, "assets"))

    File.write!(Path.join(src, "layout.html.eex"), """
    <title><%= @title %> · cohere</title>
    <nav><%= for {slug, title} <- @nav do %><a href="<%= slug %>.html"><%= title %></a><% end %></nav>
    <main><%= @content %></main>
    <footer>cohere <%= @version %></footer>
    """)

    File.write!(Path.join(src, "pages/index.md"), """
    ---
    title: Overview
    nav: 1
    description: The coherence thesis.
    ---

    A project is **coherent** when context is delivered, not discovered.
    """)

    File.write!(Path.join(src, "pages/ladder.md"), """
    ---
    title: The ladder
    nav: 2
    description: Five levels of coherence.
    ---

    ## L1

    Static guidance.
    """)

    File.write!(Path.join(src, "assets/site.css"), "body { color: #1F2A2E; }")
    src
  end

  test "build renders pages through the layout with nav and twins", %{tmp_dir: tmp} do
    src = scaffold_src!(tmp)
    out = Path.join(tmp, "docs")

    Docs.build(src: src, out: out, base_url: "https://example.test/cohere")

    index = File.read!(Path.join(out, "index.html"))
    assert index =~ "<title>Overview · cohere</title>"
    assert index =~ "<strong>coherent</strong>"
    # nav lists authored pages in nav order, then derived pages
    assert index =~ ~r/index\.html.*ladder\.html.*reference\.html.*self\.html/s

    # .md twin: title heading + body, frontmatter gone
    twin = File.read!(Path.join(out, "index.md"))
    assert twin =~ "# Overview"
    assert twin =~ "coherent"
    refute twin =~ "nav: 1"
  end

  test "build derives the reference page from compiled task moduledocs", %{tmp_dir: tmp} do
    src = scaffold_src!(tmp)
    out = Path.join(tmp, "docs")

    Docs.build(src: src, out: out, base_url: "https://example.test/cohere")

    reference = File.read!(Path.join(out, "reference.html"))
    assert reference =~ "mix cohere.design"
    assert reference =~ "mix cohere.check"
    # the derived stamp names its provenance
    assert reference =~ "derived"

    assert File.exists?(Path.join(out, "reference.md"))
  end

  test "build renders the self page from the repo's own artifacts", %{tmp_dir: tmp} do
    src = scaffold_src!(tmp)
    out = Path.join(tmp, "docs")

    Docs.build(src: src, out: out, base_url: "https://example.test/cohere")

    self_page = File.read!(Path.join(out, "self.html"))
    assert self_page =~ "System Map"
    assert self_page =~ "derived"
  end

  test "build emits llms.txt, .nojekyll, and copies assets", %{tmp_dir: tmp} do
    src = scaffold_src!(tmp)
    out = Path.join(tmp, "docs")

    Docs.build(src: src, out: out, base_url: "https://example.test/cohere")

    llms = File.read!(Path.join(out, "llms.txt"))
    assert llms =~ "# cohere"
    assert llms =~ "https://example.test/cohere/index.md"
    assert llms =~ "The coherence thesis."

    assert File.exists?(Path.join(out, ".nojekyll"))
    assert File.read!(Path.join(out, "assets/site.css")) =~ "#1F2A2E"
  end

  test "build is deterministic: same sources in, same bytes out", %{tmp_dir: tmp} do
    src = scaffold_src!(tmp)
    out = Path.join(tmp, "docs")

    Docs.build(src: src, out: out, base_url: "https://example.test/cohere")
    first = File.read!(Path.join(out, "index.html"))

    Docs.build(src: src, out: out, base_url: "https://example.test/cohere")
    assert File.read!(Path.join(out, "index.html")) == first
  end
end
