defmodule API.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias API.Router
  alias Status.Alert.Alarm
  alias Status.Alert.AlarmHandler

  setup_all do
    case Application.start(:sasl) do
      {:error, {:already_started, :sasl}} ->
        :ok = Application.stop(:sasl)
        :ok = Application.start(:sasl)

      :ok ->
        :ok
    end

    :ok = AlarmHandler.install(Alarm.alarm_types(), AlarmHandler.table_name())

    on_exit(fn ->
      _ = Application.stop(:sasl)
    end)

    :ok
  end

  test "renders an error when not matching a supported version" do
    {:ok, payload} =
      :post
      |> conn("foo")
      |> Router.call(Router.init([]))
      |> Map.get(:resp_body)
      |> Jason.decode()

    assert payload == %{
             "data" => %{
               "code" => "operation_not_found",
               "description" => "The given operation is invalid",
               "object" => "error"
             },
             "service_name" => "child_chain",
             "success" => false,
             "version" => "-"
           }
  end
end
