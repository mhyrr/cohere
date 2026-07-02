defmodule Cohere.MapTest do
  use ExUnit.Case, async: true

  alias Cohere.Map
  alias Cohere.Map.Renderer

  setup do
    project = Cohere.Fixtures.project()
    %{project: project, map: Map.build(project)}
  end

  test "assembles groups, schemas, routes, and jobs", %{map: map} do
    assert Enum.map(map.groups, & &1.name) ==
             ["Accounts", "Billing", "Encrypted", "Repo", "Vault", "Workers"]

    assert Enum.map(map.schemas, & &1.module) == [
             Fixture.Accounts.Membership,
             Fixture.Accounts.Profile,
             Fixture.Accounts.User
           ]

    assert [{FixtureWeb.Router, [_, _]}] = map.routers
    assert [%{module: Fixture.Workers.SyncWorker}] = map.jobs.workers
  end

  test "fetch_group matches by name, module, and case-insensitively", %{map: map} do
    assert Map.fetch_group(map, "Accounts").context == Fixture.Accounts
    assert Map.fetch_group(map, "accounts").context == Fixture.Accounts
    assert Map.fetch_group(map, "Fixture.Accounts").context == Fixture.Accounts
    assert Map.fetch_group(map, "Nope") == nil
  end

  describe "rendering" do
    test "is deterministic — same input, same bytes", %{map: map} do
      assert Renderer.render(map) == Renderer.render(map)
    end

    test "contains no timestamps or volatile content", %{map: map} do
      rendered = Renderer.render(map)
      refute rendered =~ ~r/\d{4}-\d{2}-\d{2}/
      refute rendered =~ ~r/\d{2}:\d{2}/
    end

    test "renders the load-bearing facts", %{map: map} do
      rendered = Renderer.render(map)

      # capabilities with absence notes
      assert rendered =~ "`ecto`"
      assert rendered =~ "`boundary` absent"

      # context entry with surface hash and API
      accounts = Enum.find(map.groups, &(&1.name == "Accounts"))
      assert rendered =~ "### Fixture.Accounts — domain `[surface:#{accounts.surface_hash}]`"
      assert rendered =~ "Account lifecycle: signup, membership, suspension."
      assert rendered =~ "create_user/1"

      # object with enum vocabulary and real FK
      assert rendered =~ "### Fixture.Accounts.User → `users`"
      assert rendered =~ "status:enum(active|suspended)"
      assert rendered =~ "belongs_to reviewed_by → Fixture.Accounts.User via reviewed_by_user_id"

      # routes relative to the web namespace, no Elixir. prefix anywhere
      assert rendered =~ "- GET /users → UserController :index"
      refute rendered =~ "Elixir."

      # embeds render as links, not as opaque fields
      assert rendered =~ "- embeds_one profile → Fixture.Accounts.Profile"
      refute rendered =~ "profile:Ecto.Embedded"

      # plumbing collapses to an infrastructure list, not context entries
      assert rendered =~ "### Infrastructure"
      assert rendered =~ "- Fixture.Encrypted.Binary (Ecto type)"
      assert rendered =~ "- Fixture.Repo (Ecto repo)"
      refute rendered =~ "### Encrypted —"

      # jobs
      assert rendered =~ "Fixture.Workers.SyncWorker — queue sync, max_attempts 5"

      # web counts pluralize correctly
      assert rendered =~ "1 router"
      refute rendered =~ "1 routers"
    end

    test "render_group slices one context with its schemas", %{map: map} do
      accounts = Enum.find(map.groups, &(&1.name == "Accounts"))
      slice = Renderer.render_group(map, accounts)

      assert slice =~ "### Fixture.Accounts — domain"
      assert slice =~ "### Fixture.Accounts.User → `users`"
      refute slice =~ "Billing"
    end
  end
end
