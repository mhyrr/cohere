defmodule Cohere.Derive.Workers do
  @moduledoc """
  Derives the background-job surface: Oban workers plus the queue and cron
  wiring that lives only in application config.

  Worker modules alone don't tell the whole story — in real apps the cron
  schedule exists exclusively in `config :my_app, Oban, plugins: [...]`, so
  this deriver reads both the compiled modules and the host app's config.
  """

  defmodule Worker do
    @moduledoc false
    defstruct module: nil, queue: nil, max_attempts: nil, unique: false, cron: nil
  end

  @doc """
  Derives `%Worker{}` entries for the given worker modules, enriched with
  cron schedules from the app's Oban config, plus the queue topology.

  Returns `%{workers: [%Worker{}], queues: [...], crontab: [...]}`.
  """
  def derive(worker_modules, app) do
    oban = oban_config(app)
    crontab = crontab(oban)

    workers =
      worker_modules
      |> Enum.sort_by(&to_string/1)
      |> Enum.map(fn module ->
        opts = worker_opts(module)

        %Worker{
          module: module,
          queue: opts[:queue],
          max_attempts: opts[:max_attempts],
          unique: Keyword.has_key?(opts, :unique),
          cron: Map.get(crontab, module)
        }
      end)

    %{workers: workers, queues: queues(oban), crontab: crontab}
  end

  defp worker_opts(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__opts__, 0) do
      module.__opts__()
    else
      []
    end
  rescue
    _ -> []
  end

  defp oban_config(app), do: Application.get_env(app, Oban) || []

  defp queues(oban) do
    case Keyword.get(oban, :queues) do
      queues when is_list(queues) ->
        Enum.map(queues, fn
          {name, limit} when is_integer(limit) -> {name, limit}
          {name, opts} when is_list(opts) -> {name, Keyword.get(opts, :limit)}
          name when is_atom(name) -> {name, nil}
        end)

      _ ->
        []
    end
  end

  defp crontab(oban) do
    oban
    |> Keyword.get(:plugins, [])
    |> Enum.flat_map(fn
      {plugin, opts} when is_list(opts) ->
        if cron_plugin?(plugin), do: Keyword.get(opts, :crontab, []), else: []

      _ ->
        []
    end)
    |> Map.new(fn
      {schedule, module} -> {module, schedule}
      {schedule, module, _opts} -> {module, schedule}
    end)
  end

  defp cron_plugin?(plugin) do
    plugin |> to_string() |> String.contains?("Cron")
  end
end
