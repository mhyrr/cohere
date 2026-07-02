defmodule Cohere.Derive.Modules do
  @moduledoc """
  Classifies every module in the host app and groups the domain layer into
  context groups.

  Classification is functional, not name-based: a schema is a module that
  exports `__schema__/1`, a repo exports `__adapter__/0`, a worker declares
  the `Oban.Worker` behaviour. Names lie (revrec's `Encrypted.Binary` lives
  in the schema layer but is a Cloak type); compiled modules don't.

  A *context group* is everything under one top-level segment of the app
  namespace (`MyApp.Deals` + `MyApp.Deals.*`). Its kind:

    * `:domain` — owns at least one Ecto schema
    * `:service` — has a context module with an API but no schemas
      (integration wrappers like `MyApp.Sheets`)
    * `:passive` — no same-named context module (module collections like
      `MyApp.Workers`)
    * `:infra` — nothing but plumbing (Application, Repo, Ecto types);
      rendered as a one-line list, not a context entry
  """

  alias Cohere.{Project, Surface}

  defmodule Group do
    @moduledoc false
    defstruct name: nil,
              context: nil,
              kind: :passive,
              doc: nil,
              functions: [],
              surface_hash: nil,
              schemas: [],
              workers: [],
              others: []
  end

  @doc """
  Returns `%{groups: [%Group{}], web: %{counts}, root: [module], skipped: [module]}`.
  """
  def inventory(%Project{} = project) do
    classified =
      project.modules
      |> Enum.map(&{&1, classify(&1)})
      |> Enum.reject(fn {_m, kind} -> kind in [:unloadable, :protocol_impl] end)

    {web, domain} = Enum.split_with(classified, fn {m, _} -> web_module?(m, project) end)

    {in_namespace, out_of_namespace} =
      Enum.split_with(domain, fn {m, _} -> namespaced?(m, project.namespace) end)

    {root, nested} =
      Enum.split_with(in_namespace, fn {m, _} -> m == project.namespace end)

    groups =
      nested
      |> Enum.group_by(fn {m, _} -> group_name(m, project.namespace) end)
      |> Enum.map(fn {name, members} -> build_group(name, members, project) end)
      |> Enum.sort_by(& &1.name)

    %{
      groups: groups,
      web: web_summary(web),
      root: Enum.map(root, fn {m, _} -> m end),
      other: Enum.map(out_of_namespace, fn {m, _} -> m end),
      routers: for({m, :router} <- classified, do: m) |> Enum.sort()
    }
  end

  @doc """
  Classifies one module by reflection. Returns one of
  `:schema`, `:embedded_schema`, `:ecto_type`, `:repo`, `:application`,
  `:router`, `:worker`, `:live_view`, `:live_component`, `:exception`,
  `:protocol`, `:protocol_impl`, `:task`, `:genserver`, `:module`, `:unloadable`.
  """
  def classify(module) do
    cond do
      not Code.ensure_loaded?(module) -> :unloadable
      function_exported?(module, :__impl__, 1) -> :protocol_impl
      function_exported?(module, :__protocol__, 1) -> :protocol
      schema?(module) -> schema_kind(module)
      function_exported?(module, :__adapter__, 0) -> :repo
      behaviour?(module, Application) -> :application
      function_exported?(module, :__routes__, 0) -> :router
      behaviour?(module, Oban.Worker) or behaviour?(module, Oban.Pro.Worker) -> :worker
      behaviour?(module, Phoenix.LiveView) -> :live_view
      behaviour?(module, Phoenix.LiveComponent) -> :live_component
      behaviour?(module, Ecto.Type) or behaviour?(module, Ecto.ParameterizedType) -> :ecto_type
      exception?(module) -> :exception
      behaviour?(module, GenServer) -> :genserver
      true -> :module
    end
  end

  @doc_max 180

  @doc """
  Compact summary from the module's @moduledoc: the first paragraph,
  truncated at a sentence boundary rather than mid-line.
  """
  def doc_line(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, %{"en" => doc}, _, _} when is_binary(doc) ->
        doc
        |> String.split("\n\n", parts: 2)
        |> hd()
        |> String.split("\n")
        |> Enum.map_join(" ", &String.trim/1)
        |> String.trim()
        |> truncate()

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp truncate(text) when byte_size(text) <= @doc_max, do: text

  defp truncate(text) do
    # Prefer a sentence boundary within budget; fall back to a hard cut.
    case Regex.run(~r/\A(.{40,#{@doc_max}}?[.!?])\s/su, text) do
      [_, sentence] -> sentence
      nil -> String.slice(text, 0, @doc_max - 1) <> "…"
    end
  end

  @infra_kinds [:application, :repo, :ecto_type, :exception]

  defp build_group(name, members, project) do
    context = Module.concat(project.namespace, name)

    context_entry =
      Enum.find(members, fn {m, kind} -> m == context and kind in [:module, :genserver] end)

    by_kind = Enum.group_by(members, fn {_m, kind} -> kind end, fn {m, _} -> m end)
    schemas = Enum.sort(Map.get(by_kind, :schema, []) ++ Map.get(by_kind, :embedded_schema, []))
    workers = Enum.sort(Map.get(by_kind, :worker, []))

    others =
      members
      |> Enum.map(fn {m, _} -> m end)
      |> Enum.reject(&(&1 in schemas or &1 in workers or (context_entry && &1 == context)))
      |> Enum.sort()

    functions = if context_entry, do: Surface.functions(context), else: []

    %Group{
      name: name,
      context: context_entry && context,
      kind: group_kind(context_entry, schemas, members),
      doc: context_entry && doc_line(context),
      functions: functions,
      surface_hash: (context_entry && Surface.hash(functions)) || nil,
      schemas: schemas,
      workers: workers,
      others: others
    }
  end

  defp group_kind(nil, _schemas, members) do
    if Enum.all?(members, fn {_m, kind} -> kind in @infra_kinds end) do
      :infra
    else
      :passive
    end
  end

  defp group_kind(_context, [], _members), do: :service
  defp group_kind(_context, _schemas, _members), do: :domain

  defp web_summary(web) do
    counts = Enum.frequencies_by(web, fn {m, kind} -> web_kind(m, kind) end)
    modules = web |> Enum.map(fn {m, _} -> m end) |> Enum.sort()
    Map.put(counts, :modules, modules)
  end

  defp web_kind(module, :module) do
    name = to_string(module)

    cond do
      String.ends_with?(name, "Controller") -> :controller
      String.ends_with?(name, "HTML") or String.ends_with?(name, "Components") -> :component
      String.ends_with?(name, "JSON") -> :view
      true -> :module
    end
  end

  defp web_kind(_module, kind), do: kind

  defp web_module?(_module, %Project{web_namespace: nil}), do: false
  defp web_module?(module, %Project{web_namespace: web}), do: namespaced?(module, web)

  defp namespaced?(module, namespace) do
    module == namespace or String.starts_with?(to_string(module), to_string(namespace) <> ".")
  end

  defp group_name(module, namespace) do
    module
    |> Module.split()
    |> Enum.drop(length(Module.split(namespace)))
    |> hd()
  end

  defp schema?(module), do: function_exported?(module, :__schema__, 1)

  defp schema_kind(module) do
    if module.__schema__(:source), do: :schema, else: :embedded_schema
  rescue
    _ -> :schema
  end

  defp exception?(module) do
    function_exported?(module, :exception, 1) and function_exported?(module, :__struct__, 0)
  end

  defp behaviour?(module, behaviour) do
    behaviours =
      module.module_info(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    behaviour in behaviours
  rescue
    _ -> false
  end
end
