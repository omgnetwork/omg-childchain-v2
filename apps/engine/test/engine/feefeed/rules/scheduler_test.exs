defmodule Engine.Feefeed.Rules.SchedulerTest do
  use ExUnit.Case, async: true
  alias Engine.Feefeed.Rules.Scheduler

  defmodule WorkerMock do
    use GenServer

    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
      {:ok, 0}
    end

    def update(pid \\ __MODULE__, orchestrator_pid \\ nil) do
      GenServer.cast(pid, {:update, orchestrator_pid})
    end

    def handle_cast({:update, _orchestrator_pid}, state) do
      {:noreply, state + 1}
    end
  end

  describe "start_link/1" do
    test "starts the genserver" do
      {:ok, scheduler_pid} = Scheduler.start_link(interval: 180, workers: [])

      assert Process.alive?(scheduler_pid)
      GenServer.stop(scheduler_pid)
    end
  end

  describe "stop/1" do
    test "stops the genserver" do
      {:ok, scheduler_pid} = Scheduler.start_link(interval: 180, workers: [])
      :ok = GenServer.stop(scheduler_pid)

      refute Process.alive?(scheduler_pid)
    end
  end

  describe "init/1" do
    test "starts ticking" do
      {:ok, subscriber_pid} = WorkerMock.start_link()
      {:ok, scheduler_pid} = Scheduler.start_link(interval: 1, workers: [subscriber_pid])
      :timer.sleep(1000)

      assert :sys.get_state(scheduler_pid) > 0

      GenServer.stop(scheduler_pid)
      GenServer.stop(subscriber_pid)
    end
  end
end
