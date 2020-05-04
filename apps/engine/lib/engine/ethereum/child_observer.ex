defmodule Engine.Ethereum.ChildObserver do
  @moduledoc """
    Reports it's health to the Monitor after start or restart and shutsdown.
  """
  use GenServer, restart: :transient

  require Logger
  @timer 100
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    monitor = Keyword.fetch!(args, :monitor)
    {:ok, _tref} = :timer.send_after(@timer, :health_checkin)
    {:ok, %{timer: @timer, monitor: monitor}}
  end

  def handle_info(:health_checkin, state) do
    :ok = GenServer.cast(state.monitor, :health_checkin)
    {:stop, :normal, state}
  end
end
