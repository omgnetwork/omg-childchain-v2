defmodule Engine.Ethereum.Authority.SubmitterTest do
  use Engine.DB.DataCase, async: false

  alias Engine.Ethereum.Authority.Submitter
  alias Status.Alert.Alarm
  alias Status.Alert.AlarmHandler

  setup do
    case Application.start(:sasl) do
      {:error, {:already_started, :sasl}} ->
        :ok = Application.stop(:sasl)
        :ok = Application.start(:sasl)
        :ok = AlarmHandler.install(Alarm.alarm_types(), AlarmHandler.table_name())

      :ok ->
        :ok
    end

    on_exit(fn ->
      Application.stop(:sasl)
    end)

    :ok
  end

  test "backs off on alert" do
    init_args = [
      enterprise: 0,
      plasma_framework: "",
      child_block_interval: 1000,
      gas_integration_fallback_order: [nil],
      opts: []
    ]

    {:ok, pid} = Submitter.start_link(init_args)
    Alarm.set(Alarm.Types.db_connection_lost(__MODULE__))
    Alarm.set(Alarm.Types.ethereum_connection_error(__MODULE__))
    Process.sleep(500)
    assert(:sys.get_state(pid).db_connection_lost)
    assert(:sys.get_state(pid).ethereum_connection_error)
    Alarm.clear(Alarm.Types.db_connection_lost(__MODULE__))
    Alarm.clear(Alarm.Types.ethereum_connection_error(__MODULE__))
    Process.sleep(500)
    refute(:sys.get_state(pid).db_connection_lost)
    refute(:sys.get_state(pid).ethereum_connection_error)
  end
end
