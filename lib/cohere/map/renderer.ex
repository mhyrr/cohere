defmodule Cohere.Map.Renderer do
  @moduledoc """
  Renders a `Cohere.Map` to markdown.

  Format goals, in priority order: deterministic (stable ordering, no
  timestamps — regeneration without code change is a no-op diff), sliceable
  (one line per fact, so a context's slice can be cut out for a work
  packet), and compact (an agent should be able to swallow a whole context
  entry without ceremony).
  """

  alias Cohere.{Map, Surface}

  @doc "Renders the whole map."
  @spec render(Map.t()) :: String.t()
  def render(%Map{} = map) do
    [
      header(map),
      capabilities(map),
      contexts(map),
      objects(map),
      routes(map),
      jobs(map),
      web(map),
      unclaimed(map)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> String.trim_trailing()
    |> Kernel.<>("\n")
  end

  @doc "Renders a single context group (used for map slices in work packets)."
  def render_group(%Map{} = map, group) do
    schemas = Enum.filter(map.schemas, &(&1.module in group.schemas))

    [
      group_entry(group),
      Enum.map(schemas, &object_entry/1)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp header(map) do
    """
    # System Map — #{map.project.app}

    > Derived from the compiled application by `mix cohere.map`. Do not edit;
    > regenerate instead. If this file disagrees with the code, the file is
    > stale — never the other way around.
    """
  end

  defp capabilities(map) do
    caps = map.project.capabilities

    detected =
      for {cap, effect} <- capability_effects(), Elixir.Map.has_key?(caps, cap) do
        "- `#{cap}` #{caps[cap]} — #{effect}"
      end

    absent =
      for {cap, note} <- absence_notes(), not Elixir.Map.has_key?(caps, cap) do
        "- `#{cap}` absent — #{note}"
      end

    """
    ## Capabilities

    #{Enum.join(detected ++ absent, "\n")}
    """
  end

  defp capability_effects do
    [
      phoenix: "routes derived from compiled routers",
      phoenix_live_view: "LiveView routes unwrapped to view modules",
      ecto: "objects and links derived from schema reflection",
      ecto_sql: "SQL adapter present",
      oban: "job surface derived (workers, queues, cron)",
      boundary: "write-path governance is compiler-checked",
      ash: "resources present (richer derivation possible)",
      tidewave:
        "runtime introspection for agents (project_eval, execute_sql_query, get_logs, get_docs)"
    ]
  end

  defp absence_notes do
    [
      boundary: "write-path governance is convention only, not compiler-checked",
      tidewave: "no runtime introspection; agents verify via tests only"
    ]
  end

  defp contexts(%Map{groups: []}), do: nil

  defp contexts(map) do
    """
    ## Contexts

    #{Enum.map_join(map.groups, "\n", &group_entry/1)}
    """
  end

  defp group_entry(group) do
    title =
      case group.context do
        nil -> "### #{group.name} — #{group.kind}"
        context -> "### #{inspect(context)} — #{group.kind} `[surface:#{group.surface_hash}]`"
      end

    [
      title,
      group.doc && "\n#{group.doc}",
      functions_block(group),
      list_line("Schemas", group.schemas),
      list_line("Workers", group.workers),
      list_line("Support", group.others)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp functions_block(%{functions: []}), do: nil

  defp functions_block(group) do
    "\n**API** (#{length(group.functions)}): #{Surface.to_line(group.functions)}"
  end

  defp list_line(_label, []), do: nil

  defp list_line(label, modules) do
    "**#{label}:** #{Enum.map_join(modules, ", ", &short_name/1)}"
  end

  defp objects(%Map{schemas: []}), do: nil

  defp objects(map) do
    """
    ## Objects

    #{Enum.map_join(map.schemas, "\n", &object_entry/1)}
    """
  end

  defp object_entry(schema) do
    source = if schema.embedded?, do: "(embedded)", else: "`#{schema.source}`"

    fields =
      Enum.map_join(schema.fields, ", ", fn f ->
        pk = if f.primary_key?, do: " pk", else: ""
        "#{f.name}:#{f.type}#{pk}"
      end)

    links = Enum.map(schema.assocs, &assoc_line/1)

    embeds =
      Enum.map(schema.embeds, fn e ->
        "- embeds_#{e.cardinality} #{e.name} → #{inspect(e.related)}"
      end)

    (["### #{inspect(schema.module)} → #{source}", "- fields: #{fields}"] ++ links ++ embeds)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  defp assoc_line(%{kind: :belongs_to} = a),
    do: "- belongs_to #{a.name} → #{inspect(a.related)} via #{a.key}"

  defp assoc_line(%{kind: :many_to_many} = a),
    do: "- many_to_many #{a.name} → #{inspect(a.related)} through #{a.through}"

  defp assoc_line(%{kind: :has_through} = a),
    do: "- has_through #{a.name} via #{inspect(a.through)}"

  defp assoc_line(a),
    do: "- #{a.kind} #{a.name} → #{inspect(a.related)}"

  defp routes(%Map{routers: []}), do: nil

  defp routes(map) do
    web_prefix = map.project.web_namespace && inspect(map.project.web_namespace) <> "."

    sections =
      Enum.map_join(map.routers, "\n", fn {router, routes} ->
        lines =
          Enum.map_join(routes, "\n", fn route ->
            verb = route.verb |> to_string() |> String.upcase()
            module = route.module |> inspect() |> strip_prefix(web_prefix)
            action = route.action && " :#{route.action}"
            "- #{verb} #{route.path} → #{module}#{action}"
          end)

        "### #{inspect(router)}\n\n#{lines}\n"
      end)

    note =
      if web_prefix,
        do: "\n_Route modules shown relative to `#{map.project.web_namespace}`._\n",
        else: ""

    """
    ## Routes
    #{note}
    #{sections}
    """
  end

  defp jobs(%Map{jobs: %{workers: [], queues: []}}), do: nil

  defp jobs(map) do
    queues =
      case map.jobs.queues do
        [] ->
          nil

        queues ->
          rendered =
            Enum.map_join(queues, ", ", fn
              {name, nil} -> to_string(name)
              {name, limit} -> "#{name}:#{limit}"
            end)

          "Queues: #{rendered}"
      end

    workers =
      Enum.map(map.jobs.workers, fn w ->
        details =
          [
            w.queue && "queue #{w.queue}",
            w.max_attempts && "max_attempts #{w.max_attempts}",
            w.unique && "unique",
            w.cron && "cron `#{w.cron}`"
          ]
          |> Enum.filter(& &1)
          |> Enum.join(", ")

        if details == "",
          do: "- #{inspect(w.module)}",
          else: "- #{inspect(w.module)} — #{details}"
      end)

    """
    ## Jobs

    #{Enum.join(Enum.reject([queues | workers], &is_nil/1), "\n")}
    """
  end

  defp web(%Map{web: web}) when web == %{}, do: nil
  defp web(%Map{project: %{web_namespace: nil}}), do: nil

  defp web(map) do
    counts =
      map.web
      |> Elixir.Map.drop([:modules])
      |> Enum.sort_by(fn {_k, count} -> -count end)
      |> Enum.map_join(", ", fn {kind, count} -> "#{count} #{format_kind(kind)}" end)

    """
    ## Web Layer — #{map.project.web_namespace}

    #{counts}. Derived counts only; the authoritative surface is the Routes section.
    """
  end

  defp unclaimed(%Map{root: [], other: []}), do: nil

  defp unclaimed(map) do
    lines =
      Enum.map(map.root, fn m -> "- #{inspect(m)} (namespace root)" end) ++
        Enum.map(map.other, fn m -> "- #{inspect(m)} (outside app namespaces)" end)

    """
    ## Unclaimed Modules

    #{Enum.join(lines, "\n")}
    """
  end

  defp format_kind(:live_view), do: "LiveViews"
  defp format_kind(:live_component), do: "LiveComponents"
  defp format_kind(:controller), do: "controllers"
  defp format_kind(:component), do: "component modules"
  defp format_kind(:view), do: "view modules"
  defp format_kind(:router), do: "routers"
  defp format_kind(kind), do: "#{kind} modules"

  defp short_name(module) do
    module |> Module.split() |> List.last()
  end

  defp strip_prefix(name, nil), do: name
  defp strip_prefix(name, prefix), do: String.replace_prefix(name, prefix, "")
end
