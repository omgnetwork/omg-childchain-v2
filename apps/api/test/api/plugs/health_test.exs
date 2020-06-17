defmodule API.Plugs.HealthTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias API.Plugs.Health
  alias Status.Alert.Alarm
  alias Status.Alert.Alarm.Types

  @moduletag :flakey

  setup do
    _ = Application.ensure_all_started(:status)
    Alarm.clear_all()
  end

  test "rejects requests if an alarm is raised" do
    Alarm.set(Types.ethereum_connection_error(__MODULE__))
    resp = Health.call(conn(:get, "/"), %{})

    assert resp.status == 503
  end

  test "accepts requests if no alarm is raised" do
    Alarm.clear_all()
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
