defmodule Engine.Ethereum.MonitorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias __MODULE__.Alarm
  alias __MODULE__.ChildProcess
  alias Engine.Ethereum.Monitor
  alias Engine.Ethereum.Monitor.AlarmHandler

  setup_all do
    _ = Application.stop(:logger)
    on_exit(fn -> Application.ensure_all_started(:logger) end)
  end

  test "that a child process gets restarted after alarm is cleared" do
    child_process_name = :child_process_name_1
    monitor_name = :monitor_name_1
    child = ChildProcess.prepare_child(child_process_name)

    {:ok, monitor_pid} =
      Monitor.start_link(
        name: monitor_name,
        alarm: Alarm,
        child_spec: child,
        alarm_handler: AlarmHandler
      )

    _ = Process.unlink(monitor_pid)
    {:links, [child_pid]} = Process.info(monitor_pid, :links)
    :erlang.trace(monitor_pid, true, [:receive])

    # the child is now killed

    true = Process.exit(Process.whereis(child_process_name), :kill)

    # we prove that we're linked to the child process and that when it gets killed
    # we get the trap exit message
    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^child_pid, :killed}}, 5_000
    {:links, links} = Process.info(monitor_pid, :links)
    assert Enum.empty?(links) == true

    # now we can clear the alarm and let the monitor restart the child process
    # and trace that the child process gets started

    clear_alarm_event = {:clear_alarm, {:ethereum_connection_error, %{}}}
    _ = AlarmHandler.handle_event(clear_alarm_event, %AlarmHandler{consumer: monitor_name})
    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :start_child}}
    # turning trace off
    :erlang.trace(monitor_pid, false, [:receive])
    # we now assert that our child was re-attached to the monitor
    assert_receive :done
    Process.sleep(100)
    {:links, children} = Process.info(monitor_pid, :links)
    assert Enum.count(children) == 1
  end

  test "that a child process does not get restarted if an alarm is cleared but it was not down" do
    child_process_name = :child_process_name_2
    monitor_name = :monitor_name_2
    child = ChildProcess.prepare_child(child_process_name)

    {:ok, monitor_pid} =
      Monitor.start_link(
        name: monitor_name,
        alarm: Alarm,
        child_spec: child,
        alarm_handler: AlarmHandler
      )

    :erlang.trace(monitor_pid, true, [:receive])
    {:links, links} = Process.info(monitor_pid, :links)

    # now we clear the alarm and let the monitor restart the child processes
    # in our case the child is alive so init should NOT be called

    clear_alarm_event = {:clear_alarm, {:ethereum_connection_error, %{}}}
    _ = AlarmHandler.handle_event(clear_alarm_event, %AlarmHandler{consumer: monitor_name})

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

    def prepare_child(name) do
      test_pid = self()
      %{id: __MODULE__, start: {__MODULE__, :start_link, [[name: name, parent: test_pid]]}}
    end

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: Keyword.fetch!(args, :name))
    end

    def init(args) do
      parent = Keyword.fetch!(args, :parent)
      Kernel.send(parent, :done)
      {:ok, %{}}
    end

    def terminate(_reason, _) do
      :ok
    end
  end

  defmodule Alarm do
    @moduledoc """
    Mocking a SASL alarm
    """

    def set(_) do
      :ok
    end

    def clear(_) do
      :ok
    end

    def main_supervisor_halted(_) do
      :ok
    end
  end
end
