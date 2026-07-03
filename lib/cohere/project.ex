defmodule Cohere.Project do
  @moduledoc """
  Discovers the host project: its OTP app, module inventory, namespaces,
  and which coherence-relevant capabilities are present.

  Capability detection is probing, never requiring: cohere has zero runtime
  dependencies, so every capability is checked with `Code.ensure_loaded?/1`
  against a marker module. More installed → more derived; nothing installed
  beyond Elixir is still a working (if sparse) map.
  """

  defstruct app: nil,
            namespace: nil,
            web_namespace: nil,
            modules: [],
            capabilities: %{},
            dir: "cohere"

  @type t :: %__MODULE__{
          app: atom(),
          namespace: module(),
          web_namespace: module() | nil,
          modules: [module()],
          capabilities: %{atom() => String.t() | nil},
          dir: String.t()
        }

  # Capability => marker module. Presence of the module in the load path is
  # the signal; the version comes from the loaded application spec.
  @probes [
    ecto: Ecto.Schema,
    ecto_sql: Ecto.Adapters.SQL,
    phoenix: Phoenix.Router,
    phoenix_live_view: Phoenix.LiveView,
    oban: Oban.Worker,
    boundary: Boundary,
    ash: Ash.Resource,
    tidewave: Tidewave
  ]

  @doc """
  Loads the project description for the current Mix project.

  Options (all default to Mix/application-derived values, overridable via
  `config :cohere, ...` in the host app):

    * `:app` — the OTP app to introspect
    * `:namespace` — base module namespace (default: camelized app name)
    * `:web_namespace` — web namespace (default: `<Namespace>Web` when present)
    * `:modules` — explicit module list (used by tests)
    * `:dir` — directory where cohere artifacts live (default `"cohere"`)
  """
  @spec load(keyword()) :: t()
  def load(opts \\ []) do
    app = opts[:app] || Mix.Project.config()[:app]
    _ = Application.load(app)

    modules = opts[:modules] || config(:modules) || app_modules(app)
    namespace = opts[:namespace] || config(:namespace) || default_namespace(app)

    web_namespace =
      opts[:web_namespace] || config(:web_namespace) || detect_web(namespace, modules)

    ignore = List.wrap(opts[:ignore] || config(:ignore) || [])

    %__MODULE__{
      app: app,
      namespace: namespace,
      web_namespace: web_namespace,
      modules: Enum.sort(modules -- ignore),
      capabilities: detect_capabilities(),
      dir: opts[:dir] || config(:dir) || "cohere"
    }
  end

  @doc "Path to the derived map file."
  def map_path(%__MODULE__{dir: dir}), do: Path.join(dir, "map.md")

  @doc "Directory holding authored intent cards."
  def intent_dir(%__MODULE__{dir: dir}), do: Path.join(dir, "intent")

  @doc "Whether a capability was detected."
  def has?(%__MODULE__{capabilities: caps}, cap), do: Map.has_key?(caps, cap)

  @doc """
  Maps each source file (relative to the project root) to the modules
  compiled from it, by reflecting over `module_info(:compile)`.

  This is how a set of changed files becomes the contexts they belong to:
  reflection over compiled artifacts, never a path→module naming convention.
  A file compiled outside the current root (e.g. a build cache on another
  machine) relativizes to an absolute path and simply won't match a
  repo-relative diff entry — it drops out rather than mapping wrongly.
  """
  @spec source_index(t()) :: %{String.t() => [module()]}
  def source_index(%__MODULE__{modules: modules}) do
    root = File.cwd!()

    Enum.reduce(modules, %{}, fn module, acc ->
      case source_file(module, root) do
        nil -> acc
        rel -> Map.update(acc, rel, [module], &[module | &1])
      end
    end)
  end

  defp source_file(module, root) do
    with true <- Code.ensure_loaded?(module),
         compile when is_list(compile) <- module.module_info(:compile),
         source when not is_nil(source) <- compile[:source] do
      source |> to_string() |> Path.relative_to(root)
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp config(key), do: Application.get_env(:cohere, key)

  defp app_modules(app) do
    case :application.get_key(app, :modules) do
      {:ok, modules} -> modules
      _ -> []
    end
  end

  defp default_namespace(app) do
    Module.concat([Macro.camelize(to_string(app))])
  end

  defp detect_web(namespace, modules) do
    web = Module.concat([to_string(namespace) <> "Web"])
    prefix = to_string(web) <> "."

    if Enum.any?(modules, fn m -> m == web or String.starts_with?(to_string(m), prefix) end) do
      web
    end
  end

  defp detect_capabilities do
    for {app, marker} <- @probes, Code.ensure_loaded?(marker), into: %{} do
      {app, app_version(app)}
    end
  end

  defp app_version(app) do
    case Application.spec(app, :vsn) do
      vsn when is_list(vsn) -> List.to_string(vsn)
      _ -> nil
    end
  end
end
