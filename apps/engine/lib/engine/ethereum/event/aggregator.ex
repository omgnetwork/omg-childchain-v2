defmodule Engine.Ethereum.Event.Aggregator do
  @moduledoc """
  This process combines all plasma contract events we're interested in and does eth_getLogs + enriches them if needed
  for all Ethereum Event Listener processes. 
  """
  use GenServer

  alias Engine.Ethereum.Event.Aggregator.Storage
  alias Engine.Ethereum.RootChain.Event
  alias ExPlasma.Encoding

  require Logger
  @timeout 55_000
  @type result() :: {:ok, list(map())} | {:error, :check_range}
  @type t() :: %__MODULE__{
          delete_events_threshold_height_blknum: pos_integer(),
          ets_bucket: atom(),
          event_signatures: list(binary()),
          events: list(atom()),
          contracts: list(binary()),
          event_interface: module(),
          opts: Keyword.t()
        }

  defstruct [
    :delete_events_threshold_height_blknum,
    :ets_bucket,
    :event_signatures,
    :events,
    :contracts,
    :event_interface,
    :opts
  ]

  @spec deposit_created(GenServer.server(), pos_integer(), pos_integer()) :: result()
  def deposit_created(server \\ __MODULE__, from_block, to_block) do
    forward_call(server, :deposit_created, from_block, to_block, @timeout)
  end

  @spec in_flight_exit_started(GenServer.server(), pos_integer(), pos_integer()) :: result()
  def in_flight_exit_started(server \\ __MODULE__, from_block, to_block) do
    forward_call(server, :in_flight_exit_started, from_block, to_block, @timeout)
  end

  @spec in_flight_exit_piggybacked(GenServer.server(), pos_integer(), pos_integer()) :: result()
  def in_flight_exit_piggybacked(server \\ __MODULE__, from_block, to_block) do
    # input and output
    forward_call(server, :in_flight_exit_piggybacked, from_block, to_block, @timeout)
  end

  @spec exit_started(GenServer.server(), pos_integer(), pos_integer()) :: result()
  def exit_started(server \\ __MODULE__, from_block, to_block) do
    forward_call(server, :exit_started, from_block, to_block, @timeout)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def init(opts) do
    contracts = opts |> Keyword.fetch!(:contracts) |> Enum.map(&Encoding.to_binary(&1))
    # events = [[signature: "ExitStarted(address,uint160)", name: :exit_started, enrich: true],..]
    events =
      opts
      |> Keyword.fetch!(:events)
      |> Enum.map(&Keyword.fetch!(&1, :name))
      |> Event.get_events()
      |> Enum.zip(Keyword.fetch!(opts, :events))
      |> Enum.reduce([], fn {signature, event}, acc -> [Keyword.put(event, :signature, signature) | acc] end)

    events_signatures =
      opts
      |> Keyword.fetch!(:events)
      |> Enum.map(&Keyword.fetch!(&1, :name))
      |> Event.get_events()

    ets_bucket = Keyword.fetch!(opts, :ets_bucket)
    event_interface = Keyword.get(opts, :event_interface, Event)
    opts = Keyword.fetch!(opts, :opts)

    {:ok,
     %__MODULE__{
       # 200 blocks of events will be kept in memory
       delete_events_threshold_height_blknum: 200,
       ets_bucket: ets_bucket,
       event_signatures: events_signatures,
       events: events,
       contracts: contracts,
       event_interface: event_interface,
       opts: opts
     }}
  end

  def handle_call({:in_flight_exit_piggybacked, from_block, to_block}, _, state) do
    names = [:in_flight_exit_output_piggybacked, :in_flight_exit_input_piggybacked]

    logs =
      Enum.reduce(names, [], fn name, acc ->
        signature =
          state.events
          |> Enum.find(fn event -> Keyword.fetch!(event, :name) == name end)
          |> Keyword.fetch!(:signature)

        logs = Storage.retrieve_log(signature, from_block, to_block, state)
        logs ++ acc
      end)

    {:reply, {:ok, logs}, state, {:continue, from_block}}
  end

  def handle_call({name, from_block, to_block}, _, state) do
    signature =
      state.events
      |> Enum.find(fn event -> Keyword.fetch!(event, :name) == name end)
      |> Keyword.fetch!(:signature)

    logs = Storage.retrieve_log(signature, from_block, to_block, state)
    {:reply, {:ok, logs}, state, {:continue, from_block}}
  end

  defp forward_call(server, event, from_block, to_block, timeout) when from_block <= to_block do
    GenServer.call(server, {event, from_block, to_block}, timeout)
  end

  defp forward_call(_, _, from_block, to_block, _) when from_block > to_block do
    _ = Logger.error("From block #{from_block} was bigger then to_block #{to_block}")
    {:error, :check_range}
  end

  def handle_continue(new_height_blknum, state) do
    _ = Storage.delete_old_logs(new_height_blknum, state)
    {:noreply, state}
  end
end
