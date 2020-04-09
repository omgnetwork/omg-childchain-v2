defmodule Engine.Ethereum.MonitorTest do
  @moduledoc false

  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias __MODULE__.ChildProcess

  use ExUnit.Case, async: true

  setup_all do
    :ok
  end

  setup do
    :ok
  end

  test "that a child process gets restarted after alarm is cleared" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, child])
    app_alarm = Alarm.ethereum_connection_error(__MODULE__)

    # the monitor is now started, we raise an alarm and kill it's child
    :ok = :alarm_handler.set_alarm(app_alarm)
    _ = Process.unlink(monitor_pid)
    {:links, [child_pid]} = Process.info(monitor_pid, :links)
    :erlang.trace(monitor_pid, true, [:receive])
    # the child is now killed
    capture_log(fn ->
      true = Process.exit(Process.whereis(ChildProcess), :kill)
    end)

    # we prove that we're linked to the child process and that when it gets killed
    # we get the trap exit message
    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^child_pid, :killed}}, 5_000
    {:links, links} = Process.info(monitor_pid, :links)
    assert Enum.empty?(links) == true
    # now we can clear the alarm and let the monitor restart the child process
    # and trace that the child process gets started
    capture_log(fn ->
      :ok = :alarm_handler.clear_alarm(app_alarm)
    end)

    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :start_child}}
    :erlang.trace(monitor_pid, false, [:receive])
    # we now assert that our child was re-attached to the monitor
    {:links, children} = Process.info(monitor_pid, :links)
    assert Enum.count(children) == 1
  end

  test "that a child process does not get restarted if an alarm is cleared but it was not down" do
    child = ChildProcess.prepare_child()
    {:ok, monitor_pid} = Monitor.start_link([Alarm, child])
    app_alarm = Alarm.ethereum_connection_error(__MODULE__)
    :ok = :alarm_handler.set_alarm(app_alarm)
    :erlang.trace(monitor_pid, true, [:receive])
    {:links, links} = Process.info(monitor_pid, :links)
    # now we clear the alarm and let the monitor restart the child processes
    # in our case the child is alive so init should NOT be called
    capture_log(fn ->
      :ok = :alarm_handler.clear_alarm(app_alarm)
    end)

    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :start_child}}, 1500
    :erlang.trace(monitor_pid, false, [:receive])
    # at this point we're just verifying that we didn't restart or start
    # another child
    assert Process.info(monitor_pid, :links) == {:links, links}
  end

  defmodule ChildProcess do
    @moduledoc """
    Mocking a child process to Monitor
    """
    use GenServer

    @spec prepare_child() :: %{id: atom(), start: tuple()}
    def prepare_child() do
      %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}}
    end

    def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def init(_), do: {:ok, %{}}

    def terminate(_reason, _) do
      :ok
    end
  end
end
