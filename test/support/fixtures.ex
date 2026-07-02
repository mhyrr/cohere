# A miniature app shape for exercising derivation. Oban is deliberately NOT a
# dependency — the fake Oban.Worker behaviour below proves capability probing
# works against duck-typed modules, exactly as it must in a host app cohere
# doesn't share deps with.

defmodule Oban.Worker do
  @callback perform(job :: term()) :: term()
end

defmodule Fixture.Accounts do
  @moduledoc "Account lifecycle: signup, membership, suspension."

  def list_users, do: []
  def get_user!(_id), do: nil
  def create_user(attrs \\ %{}), do: {:ok, attrs}
  def suspend_user(_user), do: :ok
  def child_spec(_opts), do: :ignored_by_surface
end

defmodule Fixture.Accounts.User do
  use Ecto.Schema

  schema "users" do
    field(:email, :string)
    field(:status, Ecto.Enum, values: [:active, :suspended])
    field(:tags, {:array, :string})
    belongs_to(:reviewed_by, Fixture.Accounts.User, foreign_key: :reviewed_by_user_id)
    has_many(:memberships, Fixture.Accounts.Membership)
  end
end

defmodule Fixture.Accounts.Membership do
  use Ecto.Schema

  schema "memberships" do
    belongs_to(:user, Fixture.Accounts.User)
  end
end

defmodule Fixture.Accounts.Profile do
  use Ecto.Schema

  embedded_schema do
    field(:bio, :string)
  end
end

defmodule Fixture.Billing do
  @moduledoc "Wraps the payment provider; owns no data."

  def charge(_amount), do: :ok
  def refund(_charge_id), do: :ok
end

defmodule Fixture.Workers.SyncWorker do
  @behaviour Oban.Worker

  def __opts__, do: [queue: :sync, max_attempts: 5]

  @impl true
  def perform(_job), do: :ok
end

defmodule Fixture.Encrypted.Binary do
  use Ecto.Type

  def type, do: :binary
  def cast(v), do: {:ok, v}
  def load(v), do: {:ok, v}
  def dump(v), do: {:ok, v}
end

defmodule Fixture.Repo do
  def __adapter__, do: Fixture.FakeAdapter
end

defimpl String.Chars, for: Fixture.Accounts.User do
  def to_string(user), do: "user:#{user.id}"
end

defmodule FixtureWeb.UserController do
  def init(opts), do: opts
  def call(conn, _opts), do: conn
end

defmodule FixtureWeb.Router do
  use Phoenix.Router

  get("/users", FixtureWeb.UserController, :index)
  post("/users", FixtureWeb.UserController, :create)
end

defmodule Cohere.Fixtures do
  @moduledoc false

  alias Cohere.Project

  @modules [
    Fixture.Accounts,
    Fixture.Accounts.User,
    Fixture.Accounts.Membership,
    Fixture.Accounts.Profile,
    Fixture.Billing,
    Fixture.Workers.SyncWorker,
    Fixture.Encrypted.Binary,
    Fixture.Repo,
    FixtureWeb.UserController,
    FixtureWeb.Router,
    String.Chars.Fixture.Accounts.User
  ]

  def modules, do: @modules

  def project(overrides \\ []) do
    base = [
      app: :cohere,
      modules: @modules,
      namespace: Fixture,
      web_namespace: FixtureWeb
    ]

    Project.load(Keyword.merge(base, overrides))
  end
end
