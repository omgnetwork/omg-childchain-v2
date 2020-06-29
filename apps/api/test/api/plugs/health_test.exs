defmodule API.Plugs.HealthTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias API.Plugs.Health
  alias Status.Alert.Alarm.Types
  alias Status.Alert.AlarmHandler
  alias Status.Alert.AlarmHandler.Table

  setup do
    Table.setup(AlarmHandler.table_name())
  end

  test "rejects requests if an alarm is raised" do
    AlarmHandler.handle_event({:set_alarm, Types.ethereum_connection_error(__MODULE__)}, %{
      alarms: [],
      table_name: AlarmHandler.table_name()
    })

    resp = Health.call(conn(:get, "/"), %{})

    assert resp.status == 503
  end

  test "accepts requests if no alarm is raised" do
    _ = Health.call(conn(:get, "/"), %{})
    assert :ok = call_plug(1000)
  end

  defp call_plug(0), do: :error

  defp call_plug(count) do
    status =
      :get
      |> conn("/")
      |> Health.call(%{})
      |> Map.get(:status)

    case status do
      503 ->
        Process.sleep(10)
        call_plug(count - 1)

      _ ->
        :ok
    end
  end
end
