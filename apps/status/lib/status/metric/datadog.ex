defmodule Status.Metric.Datadog do
  @moduledoc """
  Datadog connection wrapper
  """

  # we want to override Statix in :test
  # because we don't want to send metrics in unittests
  case Application.get_env(:status, :environment) do
    :test -> use Status.Metric.Statix
    _ -> use Statix, runtime_config: true
  end

  use GenServer
  require Logger

  def start_link(), do: GenServer.start_link(__MODULE__, [], [])

  def init(_opts) do
    _ = Process.flag(:trap_exit, true)
    _ = Logger.info("Starting #{inspect(__MODULE__)} and connecting to Datadog.")
    __MODULE__.connect()
    _ = Logger.info("Connection opened #{inspect(current_conn())}")
    {:ok, current_conn()}
  end

  def handle_info({:EXIT, port, reason}, %Statix.Conn{sock: __MODULE__} = state) do
    _ = Logger.error("Port in #{inspect(__MODULE__)} #{inspect(port)} exited with reason #{reason}")
    {:stop, :normal, state}
  end
end
