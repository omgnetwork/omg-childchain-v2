defmodule AlarmDetectionTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.HeightObserver
  alias Engine.Ethereum.RootChain.Rpc
  alias Status.Alert.Alarm
  alias Engine.Geth
  @moduletag :integration

  setup do
    {:ok, apps} = Application.ensure_all_started(:status)

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    port = Enum.random(35_000..40_000)
    {:ok, {geth_pid, _container_id}} = Geth.start(port)

    url = "http://127.0.0.1:#{port}"

    {:ok, pid} =
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

    %{pid: pid, geth_pid: geth_pid}
  end

  test "alarm gets raised when geth stops listening", %{pid: pid, geth_pid: geth_pid} do
    Process.flag(:trap_exit, true)
    # geth traps exits as well, we get back :parent
    Process.exit(geth_pid, :killed)

    assert_receive {:EXIT, ^geth_pid, :parent}, 60_000
    :erlang.trace(pid, true, [:receive])
    assert_receive {:trace, ^pid, :receive, {:"$gen_cast", {:set_alarm, :ethereum_connection_error}}}, 8000
    %{connection_alarm_raised: true} = :sys.get_state(pid)
  end
end
