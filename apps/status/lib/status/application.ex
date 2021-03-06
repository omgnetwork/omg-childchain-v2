defmodule Status.Application do
  @moduledoc """
  Top level application module.
  """
  use Application

  alias Status.AlarmPrinter
  alias Status.Alert.Alarm
  alias Status.Alert.AlarmHandler
  alias Status.Configuration
  alias Status.DatadogEvent.AlarmConsumer
  alias Status.Metric.Datadog
  alias Status.Metric.VmstatsSink

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    :ok = AlarmHandler.install(Alarm.alarm_types(), AlarmHandler.table_name())
    is_datadog_disabled = is_disabled?()

    children =
      case is_datadog_disabled do
        true ->
          # spandex datadog api server is able to flush when disabled?: true
          [{SpandexDatadog.ApiServer, spandex_datadog_options()}]

        false ->
          [
            {Datadog, []},
            {
              Telemetry,
              [
                release: Configuration.release(),
                current_version: Configuration.current_version()
              ]
            },
            VmstatsSink.prepare_child(),
            {SpandexDatadog.ApiServer, spandex_datadog_options()},
            {AlarmConsumer,
             [
               dd_alarm_handler: Status.DatadogEvent.AlarmHandler,
               release: Configuration.release(),
               current_version: Configuration.current_version(),
               publisher: Status.Metric.Datadog
             ]}
          ]
      end

    child = [{AlarmPrinter, [alarm_module: Alarm]}]
    Supervisor.start_link(children ++ child, strategy: :one_for_one, name: Status.Supervisor)
  end

  @spec is_disabled?() :: boolean()
  defp is_disabled?() do
    Keyword.fetch!(Configuration.tracer(), :disabled?)
  end

  defp spandex_datadog_options() do
    Configuration.spandex_datadog()
  end
end
