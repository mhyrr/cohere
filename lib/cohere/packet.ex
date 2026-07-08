defmodule Cohere.Packet do
  @moduledoc """
  Assembles a work packet: context delivered, not discovered.

  Given the contexts a task touches, the packet gathers (a) the map slice
  for those contexts, (b) their intent cards verbatim, (c) draft designs
  anchored to them — inlined loudly, they are live intent not yet distilled
  into cards — and accepted designs as pointers, (d) per-directory agent
  guidance (`AGENTS.md`/`CLAUDE.md` next to the context's source) verbatim,
  (e) plausibly related routes and jobs, and (f) pointers to runtime
  verification when Tidewave is present. The rule is *link, don't restate*:
  the packet carries the source records and points at everything else; it
  never paraphrases code into a second truth.
  """

  alias Cohere.{Design, Intent, Map, Project}
  alias Cohere.Map.Renderer

  @doc """
  Builds a work packet for the named contexts (`["Deals", "Billing"]`).

  Returns `{:ok, markdown}` or `{:error, {:unknown_contexts, names}}`.
  """
  @spec build(Project.t(), [String.t()]) :: {:ok, String.t()} | {:error, term()}
  def build(%Project{} = project, context_names) when is_list(context_names) do
    map = Map.build(project)
    cards = Intent.load_all(project)

    {found, unknown} =
      context_names
      |> Enum.map(&{&1, Map.fetch_group(map, &1)})
      |> Enum.split_with(fn {_name, group} -> group != nil end)

    case unknown do
      [] ->
        groups = Enum.map(found, fn {_name, group} -> group end)
        {:ok, render(project, map, groups, cards, Design.load_all(project))}

      _ ->
        {:error, {:unknown_contexts, Enum.map(unknown, fn {name, _} -> name end)}}
    end
  end

  @doc """
  Builds a packet for the contexts touched by a set of changed files —
  typically a branch diff (`mix cohere.packet --diff`).

  Returns `{:ok, markdown, report}` where `report` is
  `%{contexts: [name], unmapped: [file]}`, or
  `{:error, {:no_contexts, unmapped}}` when nothing mapped. The packet
  carries a scope note listing the contexts covered and the changed files
  that did not map to any — never a silent slice.
  """
  @spec build_for_files(Project.t(), [String.t()]) ::
          {:ok, String.t(), map()} | {:error, {:no_contexts, [String.t()]}}
  def build_for_files(%Project{} = project, files) when is_list(files) do
    map = Map.build(project)
    report = contexts_for_files(map, Project.source_index(project), files)

    case report.contexts do
      [] ->
        {:error, {:no_contexts, report.unmapped}}

      contexts ->
        cards = Intent.load_all(project)
        groups = Enum.map(contexts, &Map.fetch_group(map, &1))
        designs = Design.load_all(project)
        {:ok, render(project, map, groups, cards, designs, scope_section(files, report)), report}
    end
  end

  @doc """
  Resolves changed files to the context groups that own them, using a
  `%{source_path => [module]}` index (see `Cohere.Project.source_index/1`).

  Returns `%{contexts: [name], unmapped: [file]}`, contexts deduped in
  first-seen order. A file whose modules belong to no context group —
  web modules, config, migrations, non-source — lands in `unmapped`.
  """
  @spec contexts_for_files(Map.t(), %{String.t() => [module()]}, [String.t()]) :: map()
  def contexts_for_files(%Map{} = map, source_index, files) do
    index = group_index(map)

    {contexts, unmapped} =
      Enum.reduce(files, {[], []}, fn file, {ctx, un} ->
        names =
          (source_index[file] || [])
          |> Enum.map(&index[&1])
          |> Enum.reject(&is_nil/1)

        case names do
          [] -> {ctx, [file | un]}
          names -> {names ++ ctx, un}
        end
      end)

    %{contexts: contexts |> Enum.reverse() |> Enum.uniq(), unmapped: Enum.reverse(unmapped)}
  end

  @doc "Reverse index: every module owned by a context group → the group name."
  @spec group_index(Map.t()) :: %{module() => String.t()}
  def group_index(%Map{groups: groups}) do
    for group <- groups,
        module <- group_modules(group),
        into: %{},
        do: {module, group.name}
  end

  defp group_modules(group) do
    [group.context | group.schemas ++ group.workers ++ group.others]
    |> Enum.reject(&is_nil/1)
  end

  @guidance_files ~w(AGENTS.md CLAUDE.md)

  @doc """
  Guidance files (`AGENTS.md`, `CLAUDE.md`) living in the directories a
  group's modules compile from — source-index-derived, not path convention.

  Root-level guidance is excluded: every harness loads it already, so the
  packet keeps it as a pointer (DEC-PAC-004 in
  `cohere/design/packet-sources.md`).
  """
  @spec guidance_paths(%{String.t() => [module()]}, map()) :: [String.t()]
  def guidance_paths(source_index, group) do
    modules = MapSet.new(group_modules(group))

    source_index
    |> Enum.filter(fn {_path, mods} -> Enum.any?(mods, &(&1 in modules)) end)
    |> Enum.map(fn {path, _mods} -> Path.dirname(path) end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == "."))
    |> Enum.sort()
    |> Enum.flat_map(fn dir ->
      for file <- @guidance_files,
          path = Path.join(dir, file),
          File.exists?(path),
          do: path
    end)
  end

  defp render(project, map, groups, cards, designs, scope \\ nil) do
    source_index = Project.source_index(project)

    [
      header(project, groups),
      scope,
      inflight_section(map, groups, designs),
      Enum.map(groups, &context_section(project, map, &1, cards, designs, source_index)),
      runtime_section(project),
      pointers_section(project)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  @unmapped_cap 25

  defp scope_section(files, %{contexts: contexts, unmapped: unmapped}) do
    """
    > **Branch scope** — assembled from #{length(files)} changed file(s).
    > Contexts touched: #{Enum.join(contexts, ", ")}.
    #{unmapped_note(unmapped)}
    """
  end

  defp unmapped_note([]), do: ">\n> All changed files mapped to a context."

  defp unmapped_note(unmapped) do
    shown = Enum.take(unmapped, @unmapped_cap)
    more = length(unmapped) - length(shown)
    tail = if more > 0, do: "\n> …and #{more} more.", else: ""

    ">\n> #{length(unmapped)} changed file(s) did not map to a context " <>
      "(web, config, migrations, or non-source). Web files are not yet traced " <>
      "to the domain contexts they call — that needs the call-topology deriver. " <>
      "Verify these by hand:\n" <>
      Enum.map_join(shown, "\n", &"> - #{&1}") <> tail
  end

  defp header(project, groups) do
    names = Enum.map_join(groups, ", ", & &1.name)

    """
    # Work Packet — #{names}

    > Assembled by `mix cohere.packet` for app `#{project.app}`. Sources of
    > truth: the derived map (`#{Project.map_path(project)}`), the intent
    > cards, and the code itself. Link, don't restate — do not copy facts
    > from here into other documents.
    """
  end

  defp context_section(project, map, group, cards, designs, source_index) do
    card = Enum.find(cards, &(&1.context == group.context))

    [
      "## Context: #{group.context && inspect(group.context)}#{if group.context == nil, do: group.name}\n",
      Renderer.render_group(map, group),
      routes_slice(map, group),
      card_slice(project, card, group),
      designs_slice(map, group, designs),
      guidance_slice(source_index, group)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # Drafts are live intent not yet distilled into cards — the one thing a
  # packet holder cannot discover from map + cards. Rendered once per
  # packet, not per context (DEC-PAC-002).
  defp inflight_section(map, groups, designs) do
    drafts =
      groups
      |> Enum.flat_map(&Design.anchored_to(designs, map, &1))
      |> Enum.uniq_by(& &1.slug)
      |> Enum.filter(&(&1.status == :draft))

    case drafts do
      [] ->
        nil

      drafts ->
        """
        ## In-flight designs

        > Draft designs anchored to this packet's contexts: someone is
        > mid-change here, and this intent is not yet distilled into cards.
        > Read before designing against this ground.
        """ <> "\n" <> Enum.map_join(drafts, "\n", &draft_excerpt/1)
    end
  end

  defp draft_excerpt(doc) do
    [
      "### #{doc.slug} (draft#{doc.date && ", #{doc.date}"}) — anchors: #{Enum.join(doc.contexts, ", ")}\n",
      "_Excerpt; full doc at #{doc.path}._\n",
      excerpt(doc, "Problem"),
      excerpt(doc, "Promised surface")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # Comment-only sections render as absent — a skeleton's template comment
  # is not content, mirroring INV-DES-003's rule for refs.
  defp excerpt(doc, heading) do
    content =
      (doc.sections[heading] || "")
      |> String.replace(~r/<!--.*?-->/s, "")
      |> String.trim()

    if content == "", do: nil, else: "**#{heading}**\n\n#{content}\n"
  end

  # Accepted designs are pointers, never inlined: their durable content
  # lives in the cards by construction (DEC-PAC-001).
  defp designs_slice(map, group, designs) do
    accepted =
      designs
      |> Design.anchored_to(map, group)
      |> Enum.filter(&(&1.status == :accepted))

    case accepted do
      [] ->
        nil

      docs ->
        """
        ### Designs (accepted — durable content lives in the card)

        #{Enum.map_join(docs, "\n", &"- `#{&1.slug}`#{&1.date && " (#{&1.date})"} — #{&1.path}")}
        """
    end
  end

  defp guidance_slice(source_index, group) do
    case guidance_paths(source_index, group) do
      [] ->
        nil

      paths ->
        Enum.map_join(paths, "\n", fn path ->
          """
          ### Guidance (#{path})

          #{String.trim_trailing(File.read!(path))}
          """
        end)
    end
  end

  defp card_slice(project, nil, group) do
    slug = Macro.underscore(group.name)

    "### Intent\n\n_No intent card for this context. If durable intent exists " <>
      "(invariants, decisions), generate one: `mix cohere.gen.intent #{slug}` " <>
      "(cards live in #{Project.intent_dir(project)}/)._\n"
  end

  defp card_slice(_project, card, _group) do
    """
    ### Intent (#{card.path})

    #{String.trim_trailing(card.body)}
    """
  end

  defp routes_slice(map, group) do
    tokens = name_tokens(group.name)

    matches =
      for {_router, routes} <- map.routers,
          route <- routes,
          route_matches?(route, tokens) do
        verb = route.verb |> to_string() |> String.upcase()
        "- #{verb} #{route.path} → #{inspect(route.module)}#{route.action && " :#{route.action}"}"
      end

    case matches do
      [] ->
        nil

      matches ->
        """
        ### Routes (name-matched heuristic — verify against the full map)

        #{Enum.join(matches, "\n")}
        """
    end
  end

  defp route_matches?(route, tokens) do
    name = inspect(route.module)
    Enum.any?(tokens, &String.contains?(name, &1))
  end

  # "Deals" → ["Deals", "Deal"]; "Billing" → ["Billing"]
  defp name_tokens(name) do
    if String.ends_with?(name, "s") do
      [name, String.trim_trailing(name, "s")]
    else
      [name]
    end
  end

  defp runtime_section(project) do
    if Project.has?(project, :tidewave) do
      """
      ## Runtime verification

      Tidewave is installed: exercise the real verbs in the running app
      instead of reasoning about them. `project_eval` to call context
      functions, `execute_sql_query` to check persisted state, `get_logs`
      to confirm side effects. Behavior claims about this change should be
      verified in the runtime, not inferred from source.
      """
    else
      """
      ## Runtime verification

      No runtime introspection detected (Tidewave not installed). Verify
      behavior through the test suite; do not claim runtime behavior that
      tests don't cover.
      """
    end
  end

  defp pointers_section(project) do
    pointers =
      [
        {"AGENTS.md", "stack-level guidance"},
        {"CLAUDE.md", "project guidance"},
        {"usage-rules.md", "dependency usage rules"},
        {Project.map_path(project), "full derived map"}
      ]
      |> Enum.filter(fn {path, _} -> File.exists?(path) end)
      |> Enum.map(fn {path, label} -> "- #{path} — #{label}" end)

    case pointers do
      [] ->
        nil

      pointers ->
        """
        ## Pointers

        #{Enum.join(pointers, "\n")}
        """
    end
  end
end
