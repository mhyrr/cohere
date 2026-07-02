defmodule Cohere.Packet do
  @moduledoc """
  Assembles a work packet: context delivered, not discovered.

  Given the contexts a task touches, the packet gathers (a) the map slice
  for those contexts, (b) their intent cards verbatim, (c) plausibly related
  routes and jobs, and (d) pointers to runtime verification when Tidewave is
  present. The rule is *link, don't restate*: the packet carries the source
  records and points at everything else; it never paraphrases code into a
  second truth.
  """

  alias Cohere.{Intent, Map, Project}
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
        {:ok, render(project, map, groups, cards)}

      _ ->
        {:error, {:unknown_contexts, Enum.map(unknown, fn {name, _} -> name end)}}
    end
  end

  defp render(project, map, groups, cards) do
    [
      header(project, groups),
      Enum.map(groups, &context_section(project, map, &1, cards)),
      runtime_section(project),
      pointers_section(project)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
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

  defp context_section(project, map, group, cards) do
    card = Enum.find(cards, &(&1.context == group.context))

    [
      "## Context: #{group.context && inspect(group.context)}#{if group.context == nil, do: group.name}\n",
      Renderer.render_group(map, group),
      routes_slice(map, group),
      card_slice(project, card, group)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
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
