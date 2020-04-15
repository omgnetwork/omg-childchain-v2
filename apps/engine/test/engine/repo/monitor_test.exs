defmodule Engine.Repo.MonitorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias __MODULE__.ChildProcess
  alias Engine.Repo.Monitor

  test "that init/1 creates state and starts the child ", %{test: test_name} do
    child_spec = Engine.Repo.child_spec(pool_size: 1, name: :test_1)
    {:ok, monitor} = Monitor.init(name: test_name, child_spec: child_spec)
    assert Process.alive?(monitor.child.pid)
    assert is_map(monitor.backoff)
  end

  test "killed repo gets restarted in backoff time", %{test: test_name} do
    child_spec = Engine.Repo.child_spec(pool_size: 1, name: :test_repo_22)
    backoff_min = 10
    backoff_max = 50
    health_check_after_crash = 10

    {:ok, monitor_pid} =
      Monitor.start_link(
        name: test_name,
        child_spec: child_spec,
        backoff_min: backoff_min,
        backoff_max: backoff_max,
        health_check_after_crash: health_check_after_crash
      )

    repo_pid = Process.whereis(:test_repo_22)
    :erlang.trace(monitor_pid, true, [:receive])
    find_and_stop(:test_repo_22)

    # we get an exit message, which producess a timeout message of backoff amount, the underlying Repo sends :ack after
    # which we clear the alarm

    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^repo_pid, :find_and_stop}}
    assert_receive {:trace, ^monitor_pid, :receive, {:timeout, _ref, :restart}}, backoff_max + backoff_min
    # internal OTP msg
    assert_receive {:trace, ^monitor_pid, :receive, {:ack, new_repo_pid, {:ok, new_repo_pid}}}
    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :ack}}
    assert_receive {:trace, ^monitor_pid, :receive, :timeout}
    assert :sys.get_state(monitor_pid).child.pid == new_repo_pid
  end

  test "monitor can survive a restart", %{test: test_name} do
    child_spec = Engine.Repo.child_spec(pool_size: 1, name: :test_repo_3)
    backoff_min = 10
    backoff_max = 50
    health_check_after_crash = 10

    {:ok, temp_monitor_pid} =
      Monitor.start_link(
        name: test_name,
        child_spec: child_spec,
        backoff_min: backoff_min,
        backoff_max: backoff_max,
        health_check_after_crash: health_check_after_crash
      )

    {:links, children} = Process.info(temp_monitor_pid, :links)
    repo_child = hd(children -- [self()])
    Process.monitor(temp_monitor_pid)
    Process.monitor(repo_child)
    :ok = GenServer.stop(temp_monitor_pid)
    assert_receive {:DOWN, _ref, :process, ^repo_child, :normal}
    assert_receive {:DOWN, _ref, :process, ^temp_monitor_pid, :normal}

    {:ok, monitor_pid} =
      Monitor.start_link(
        name: test_name,
        child_spec: child_spec,
        backoff_min: backoff_min,
        backoff_max: backoff_max,
        health_check_after_crash: health_check_after_crash
      )

    repo_pid = Process.whereis(:test_repo_3)
    :erlang.trace(monitor_pid, true, [:receive])
    find_and_stop(:test_repo_3)

    # we get an exit message, which producess a timeout message of backoff amount, the underlying Repo sends :ack after
    # which we clear the alarm

    assert_receive {:trace, ^monitor_pid, :receive, {:EXIT, ^repo_pid, :find_and_stop}}
    assert_receive {:trace, ^monitor_pid, :receive, {:timeout, _ref, :restart}}, backoff_max + backoff_min
    # internal OTP msg
    assert_receive {:trace, ^monitor_pid, :receive, {:ack, new_repo_pid, {:ok, new_repo_pid}}}
    assert_receive {:trace, ^monitor_pid, :receive, {:"$gen_cast", :ack}}
    assert_receive {:trace, ^monitor_pid, :receive, :timeout}
    assert :sys.get_state(monitor_pid).child.pid == new_repo_pid
  end

  defp find_and_stop(name) do
    case Process.whereis(name) do
      pid when is_pid(pid) -> Supervisor.stop(pid, :find_and_stop, 100)
      nil -> find_and_stop(name)
    end
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
end
