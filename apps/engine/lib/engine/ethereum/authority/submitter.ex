defmodule Engine.Ethereum.Authority.Submitter do
  @moduledoc """
  Periodic block submitter 
  """

  alias Engine.DB.Block

  # alias Engine.Ethereum.Authority.Submitter.External

  require Logger

  defstruct [:block_provider, :plasma_framework, :child_block_interval, :finality_margin, :opts]

  def start_link(init_arg) do
    name = Keyword.get(init_arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  def init(init_arg) do
    plasma_framework = Keyword.fetch!(init_arg, :plasma_framework)
    child_block_interval = Keyword.fetch!(init_arg, :child_block_interval)
    opts = Keyword.fetch!(init_arg, :opts)
    # stubbing this while I don't have a DB ready
    block_provider = Keyword.get(init_arg, :block_provider, Block)
    event_bus = Keyword.get(init_arg, :event_bus, Bus)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    state = %__MODULE__{
      block_provider: block_provider,
      plasma_framework: plasma_framework,
      child_block_interval: child_block_interval,
      opts: opts
    }

    {:ok, state}
  end

  def handle_info({:internal_event_bus, :ethereum_new_height, _new_height}, state) do
    # next_child_block = External.next_child_block(state.plasma_framework, opts)
    # previous_child_block = next_child_block - state.child_block_interval
    # blocks = state.block_provider.get_all_from(previous_child_block)
    # :ok = Core.adjust_gas_and_submit(blocks)
    {:noreply, state}
  end
end
