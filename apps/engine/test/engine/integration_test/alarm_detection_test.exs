defmodule AlarmDetectionTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.HeightObserver
  alias Engine.Ethereum.RootChain.Rpc
  alias Engine.Geth
  alias Status.Alert.Alarm
  @moduletag :integration

  setup do
    {:ok, apps} = Application.ensure_all_started(:status)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    port = Enum.random(35_000..40_000)
    {:ok, {geth_pid, _container_id}} = Geth.start(port)

    on_exit(fn ->
      case Process.alive?(geth_pid) do
        true -> GenServer.stop(geth_pid)
        false -> :ok
      end
    end)

    url = "http://127.0.0.1:#{port}"

    {:ok, height_observer_pid} =
      start_supervised(
        {HeightObserver,
         name: HeightObserver,
         opts: [url: url],
         check_interval_ms: 8000,
         stall_threshold_ms: 30_000,
         eth_module: Rpc,
         alarm_module: Alarm,
         event_bus_module: Bus}
      )

    %{height_observer_pid: height_observer_pid, geth_pid: geth_pid}
  end

  test "alarm gets raised when geth stops listening", %{
    height_observer_pid: height_observer_pid,
    # repo_monitor_pid: repo_monitor_pid,
    geth_pid: geth_pid
  } do
    Process.link(geth_pid)
    Process.flag(:trap_exit, true)
    # geth traps exits as well, we get back :parent
    Process.exit(geth_pid, :killed)

    assert_receive {:EXIT, ^geth_pid, _}, 10_000
    :erlang.trace(height_observer_pid, true, [:receive])

    assert_receive {:trace, ^height_observer_pid, :receive, {:"$gen_cast", {:set_alarm, :ethereum_connection_error}}},
                   16_000

    %{ethereum_connection_error: true} = :sys.get_state(height_observer_pid)
    :erlang.trace(height_observer_pid, false, [:receive])
  end
end
