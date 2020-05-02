defmodule Engine.Ethereum.Event.EventListener.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog.
  We don't want to pattern match on :ok to Datadog because the connection
  towards the statsd client can be intermittent and sending would be unsuccessful and that
  would trigger the removal of telemetry handler. But because we have monitors in place,
  that eventually recover the connection to Statsd handlers wouldn't exist anymore and metrics
  wouldn't be published.
  """

  import Status.Metric.Event, only: [name: 2]

  alias Status.Metric.Datadog
  alias Status.Metric.Tracer

  @supported_events [
    [:process, Engine.Ethereum.EventListener],
    [:trace, Engine.Ethereum.EventListener],
    [:trace, Engine.Ethereum.Listener.Core]
  ]
  def supported_events(), do: @supported_events

  def handle_event([:process, Engine.Ethereum.EventListener], %{events: events}, state, _config) do
    _ = Datadog.gauge(name(state.service_name, :events), length(events))
  end

  def handle_event([:process, Engine.Ethereum.EventListener], %{}, state, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(state.service_name, :message_queue_len), value)
  end
end
