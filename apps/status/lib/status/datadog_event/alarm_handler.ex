defmodule Status.DatadogEvent.AlarmHandler do
  @moduledoc """
     Is notified of raised and cleared alarms and casts them to AlarmConsumer process.
  """

  require Logger

  def init([reporter]) do
    {:ok, reporter}
  end

  def handle_call(_request, reporter), do: {:ok, :ok, reporter}

  def handle_event({:set_alarm, _alarm_details} = alarm, reporter) do
    :ok = GenServer.cast(reporter, alarm)
    {:ok, reporter}
  end

  def handle_event({:clear_alarm, _alarm_details} = alarm, reporter) do
    :ok = GenServer.cast(reporter, alarm)
    {:ok, reporter}
  end

  def handle_event(event, reporter) do
    _ = Logger.info("#{__MODULE__} got event: #{inspect(event)}. Ignoring.")
    {:ok, reporter}
  end
end
