defmodule Status.Metric.Event do
  @moduledoc """
  A centralised repository of all emitted event types with description.
  """

  @services [
    :depositor,
    :in_flight_exiter,
    :piggybacker,
    :standard_exiter
  ]

  def name(:eventer_message_queue_len), do: "eventer_message_queue_len"

  def name(service, :events) when service in @services, do: events_name(service)

  def name(service, :message_queue_len) when service in @services, do: message_queue_len_name(service)

  defp events_name(:depositor), do: "depositor_ethereum_events"
  defp events_name(:in_flight_exiter), do: "in_flight_exit_ethereum_events"
  defp events_name(:piggybacker), do: "piggyback_ethereum_events"
  defp events_name(:standard_exiter), do: "standard_exiter_ethereum_events"

  defp message_queue_len_name(:depositor), do: "depositor_message_queue_len"
  defp message_queue_len_name(:in_flight_exiter), do: "in_flight_exit_message_queue_len"
  defp message_queue_len_name(:piggybacker), do: "piggybacker_message_queue_len"
  defp message_queue_len_name(:standard_exiter), do: "standard_exiter_message_queue_len"
end
