defmodule Engine.Ethereum.Event.Coordinator do
  @moduledoc """
  Synchronizes services on root chain height, see `Coordinator.Core`
  """
  use GenServer

  alias Engine.Ethereum.Event.Coordinator.Core
  alias Engine.Ethereum.Event.Coordinator.SyncGuide
  alias Engine.Ethereum.Height

  require Logger

  # use Spandex.Decorators

  @doc """
  Notifies that calling service with name `service_name` is synced up to height `synced_height`.
  `synced_height` is the height that the service is synced when calling this function.
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "check_in/2")
  @spec check_in(non_neg_integer(), atom()) :: :ok
  def check_in(synced_height, service_name) do
    GenServer.call(__MODULE__, {:check_in, synced_height, service_name})
  end

  @doc """
  Gets Ethereum height that services can synchronize up to.
  """
  # @decorate span(service: :ethereum_event_listener, type: :backend, name: "get_sync_info/0")
  @spec get_sync_info() :: SyncGuide.t() | :nosync
  def get_sync_info() do
    GenServer.call(__MODULE__, :get_sync_info)
  end

  @spec start_link(Core.configs_services()) :: GenServer.on_start()
  def start_link(configs_services) do
    GenServer.start_link(__MODULE__, configs_services, name: __MODULE__)
  end

  def init({args, configs_services}) do
    {:ok, {args, configs_services}, {:continue, :setup}}
  end

  def handle_continue(:setup, {args, configs_services}) do
    _ = Logger.info("Starting #{__MODULE__} service. #{inspect({args, configs_services})}")
    metrics_collection_interval = Keyword.fetch!(args, :metrics_collection_interval)

    {:ok, rootchain_height} = Height.get()
    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    state = Core.init(configs_services, rootchain_height)

    configs_services |> Map.keys() |> request_sync()

    {:ok, _} = :timer.send_interval(metrics_collection_interval, self(), :send_metrics)

    _ = Logger.info("Started #{inspect(__MODULE__)}")
    {:noreply, state}
  end

  def handle_info(:send_metrics, state) do
    :ok = :telemetry.execute([:process, __MODULE__], %{}, state)
    {:noreply, state}
  end

  def handle_info({:internal_event_bus, :ethereum_new_height, root_chain_height}, state) do
    {:ok, state} = Core.update_root_chain_height(state, root_chain_height)
    {:noreply, state}
  end

  def handle_call({:check_in, synced_height, service_name}, {pid, _ref}, state) do
    _ = Logger.debug("#{inspect(service_name)} checks in on height #{inspect(synced_height)}")

    {:ok, state} = Core.check_in(state, pid, synced_height, service_name)
    {:reply, :ok, state}
  end

  def handle_call(:get_sync_info, {pid, _}, state) do
    {:reply, Core.get_synced_info(state, pid), state}
  end

  def handle_call(:get_ethereum_heights, _from, state) do
    {:reply, {:ok, Core.get_ethereum_heights(state)}, state}
  end

  defp request_sync(services) do
    Enum.each(services, fn service -> GenServer.cast(service, :sync) end)
  end
end
