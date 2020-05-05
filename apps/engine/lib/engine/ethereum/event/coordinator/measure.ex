defmodule Engine.Ethereum.Event.Coordinator.Measure do
  @moduledoc """
  Counting business metrics sent to Datadog
  """

  import Status.Metric.Event, only: [name: 2]

  alias Engine.Ethereum.Event.Coordinator
  alias Status.Metric.Datadog

  def handle_event([:process, Coordinator], _, state, _config) do
    value =
      self()
      |> Process.info(:message_queue_len)
      |> elem(1)

    _ = Datadog.gauge(name(state.service_name, :message_queue_len), value)
  end
end
