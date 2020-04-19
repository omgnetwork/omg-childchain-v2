defmodule Status.Application do
  @moduledoc """
  Top level application module.
  """
  use Application

  alias Status.AlarmPrinter
  alias Status.Alert.Alarm
  alias Status.Alert.AlarmHandler
  alias Status.DatadogEvent.AlarmConsumer
  alias Status.Metric.Datadog
  alias Status.Metric.Tracer
  alias Status.Metric.VmstatsSink

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    is_datadog_disabled = is_disabled?()

    children =
      case is_datadog_disabled do
        true ->
          # spandex datadog api server is able to flush when disabled?: true
          [{SpandexDatadog.ApiServer, spandex_datadog_options()}]

        false ->
          [
            {Status.Metric.StatsdMonitor, [alarm_module: Alarm, child_module: Datadog]},
            VmstatsSink.prepare_child(),
            {SpandexDatadog.ApiServer, spandex_datadog_options()},
            {AlarmConsumer,
             [
               dd_alarm_handler: Status.DatadogEvent.AlarmHandler,
               release: Application.get_env(:status, :release),
               current_version: Application.get_env(:status, :current_version),
               publisher: Status.Metric.Datadog
             ]}
          ]
      end

    child = [{AlarmPrinter, [alarm_module: Alarm]}]
    Supervisor.start_link(children ++ child, strategy: :one_for_one, name: Status.Supervisor)
  end

  def start_phase(:install_alarm_handler, _start_type, _phase_args) do
    :ok = AlarmHandler.install(Alarm.alarm_types())
  end

  @spec is_disabled?() :: boolean()
  defp is_disabled?() do
    Keyword.get(Application.get_env(:status, Tracer) || [], :disabled?, true)
  end

  defp spandex_datadog_options() do
    config = Application.get_all_env(:spandex_datadog)
    config_host = config[:host]
    config_port = config[:port]
    config_batch_size = config[:batch_size]
    config_sync_threshold = config[:sync_threshold]
    config_http = config[:http]
    spandex_datadog_options(config_host, config_port, config_batch_size, config_sync_threshold, config_http)
  end

  defp spandex_datadog_options(config_host, config_port, config_batch_size, config_sync_threshold, config_http) do
    [
      host: config_host || "localhost",
      port: config_port || 8126,
      batch_size: config_batch_size || 10,
      sync_threshold: config_sync_threshold || 100,
      http: config_http || HTTPoison
    ]
  end
end
