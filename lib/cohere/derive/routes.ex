defmodule Cohere.Derive.Routes do
  @moduledoc """
  Derives the HTTP/LiveView surface from compiled Phoenix routers.

  Routes are compile-time data (`__routes__/0`), so no server or database is
  needed — this runs in CI. LiveView routes are unwrapped to the LiveView
  module and action rather than reported as `Phoenix.LiveView.Plug`.
  """

  defmodule Route do
    @moduledoc false
    defstruct verb: nil, path: nil, module: nil, action: nil, kind: :http
  end

  @doc "Derives routes for every router module in the given list."
  def derive(router_modules) do
    router_modules
    |> Enum.sort_by(&to_string/1)
    |> Enum.map(fn router -> {router, routes(router)} end)
  end

  @doc "Routes for one router, in definition order."
  def routes(router) do
    router.__routes__()
    |> Enum.map(&describe/1)
    |> Enum.reject(&is_nil/1)
  rescue
    _ -> []
  end

  @doc false
  def describe(route) do
    case live_view(route) do
      {module, action} ->
        %Route{verb: :live, path: route.path, module: module, action: action, kind: :live}

      nil ->
        %Route{
          verb: route.verb,
          path: route.path,
          module: route.plug,
          action: plug_action(route.plug_opts),
          kind: kind(route)
        }
    end
  end

  defp live_view(%{metadata: %{phoenix_live_view: {module, action, _opts, _extra}}}),
    do: {module, action}

  defp live_view(%{metadata: %{phoenix_live_view: {module, action}}}), do: {module, action}
  defp live_view(_), do: nil

  defp plug_action(action) when is_atom(action), do: action
  defp plug_action(_), do: nil

  defp kind(%{verb: :*}), do: :forward
  defp kind(_), do: :http
end
