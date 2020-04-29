defmodule Status.Metric.Datadog do
  @moduledoc """
  Datadog connection wrapper - Statix
  """
  use GenServer
  use Statix, runtime_config: true

  alias Status.Configuration
  require Logger

  @doc """
  Returns child_specs for the given metric setup, to be included e.g. in Supervisor's children.
  """
  @spec prepare_child() :: Supervisor.child_spec()
  def prepare_child() do
    %{id: :datadog_statix_worker, start: {__MODULE__, :start_link, []}}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def init(_opts) do
    _ = Process.flag(:trap_exit, true)
    statix = Configuration.statix()
    _ = Logger.info("Starting #{inspect(__MODULE__)} and connecting to Datadog via #{inspect(statix)}.")
    __MODULE__.connect()
    _ = Logger.info("Connection opened #{inspect(current_conn())}")
    {:ok, current_conn()}
  end

  def handle_info({:EXIT, port, reason}, %Statix.Conn{sock: __MODULE__} = state) do
    _ = Logger.error("Port in #{inspect(__MODULE__)} #{inspect(port)} exited with reason #{reason}")
    {:stop, :normal, state}
  end
end
