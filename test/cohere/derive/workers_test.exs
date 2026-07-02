defmodule Cohere.Derive.WorkersTest do
  use ExUnit.Case, async: false

  alias Cohere.Derive.Workers

  setup do
    Application.put_env(:cohere, Oban,
      queues: [default: 10, sync: [limit: 2]],
      plugins: [
        {Oban.Plugins.Cron, crontab: [{"*/5 * * * *", Fixture.Workers.SyncWorker}]}
      ]
    )

    on_exit(fn -> Application.delete_env(:cohere, Oban) end)
  end

  test "reads worker opts from the module and cron from app config" do
    %{workers: [worker], queues: queues, crontab: crontab} =
      Workers.derive([Fixture.Workers.SyncWorker], :cohere)

    assert worker.module == Fixture.Workers.SyncWorker
    assert worker.queue == :sync
    assert worker.max_attempts == 5
    assert worker.cron == "*/5 * * * *"

    assert queues == [default: 10, sync: 2]
    assert crontab == %{Fixture.Workers.SyncWorker => "*/5 * * * *"}
  end

  test "degrades gracefully without oban config" do
    Application.delete_env(:cohere, Oban)

    %{workers: [worker], queues: [], crontab: crontab} =
      Workers.derive([Fixture.Workers.SyncWorker], :cohere)

    assert worker.cron == nil
    assert crontab == %{}
  end
end
