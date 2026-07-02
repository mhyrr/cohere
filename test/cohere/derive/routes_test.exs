defmodule Cohere.Derive.RoutesTest do
  use ExUnit.Case, async: true

  alias Cohere.Derive.Routes

  test "derives routes from a compiled router" do
    [{FixtureWeb.Router, routes}] = Routes.derive([FixtureWeb.Router])

    assert [
             %{verb: :get, path: "/users", module: FixtureWeb.UserController, action: :index},
             %{verb: :post, path: "/users", module: FixtureWeb.UserController, action: :create}
           ] = routes
  end

  test "unwraps LiveView routes to the view module (synthetic route shape)" do
    route = %{
      verb: :get,
      path: "/deals",
      plug: Phoenix.LiveView.Plug,
      plug_opts: :index,
      metadata: %{phoenix_live_view: {FixtureWeb.DealLive, :index, [], %{}}}
    }

    described = Routes.describe(route)
    assert described.verb == :live
    assert described.module == FixtureWeb.DealLive
    assert described.action == :index
    assert described.kind == :live
  end

  test "forward routes are marked" do
    route = %{verb: :*, path: "/mail", plug: Some.Plug, plug_opts: [], metadata: %{}}
    assert Routes.describe(route).kind == :forward
  end
end
