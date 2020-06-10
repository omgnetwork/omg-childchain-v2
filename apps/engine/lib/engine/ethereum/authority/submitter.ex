defmodule Engine.Ethereum.Authority.Submitter do
  @moduledoc """
  Periodic block submitter 
  """

  alias Engine.DB.PlasmaBlock
  alias Engine.Ethereum.Authority.Submitter.Core
  alias Engine.Ethereum.Authority.Submitter.External
  alias Engine.Ethereum.Height

  require Logger

  defstruct [:vault, :plasma_framework, :child_block_interval, :height, :opts]

  def push(server \\ __MODULE__) do
    GenServer.cast(server, :submit)
  end

  def start_link(init_arg) do
    name = Keyword.get(init_arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  def init(init_arg) do
    vault = Keyword.fetch!(init_arg, :vault)
    plasma_framework = Keyword.fetch!(init_arg, :plasma_framework)
    child_block_interval = Keyword.fetch!(init_arg, :child_block_interval)
    opts = Keyword.fetch!(init_arg, :opts)
    event_bus = Keyword.get(init_arg, :event_bus, Bus)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
    height = Height.get()

    state = %__MODULE__{
      vault: vault,
      plasma_framework: plasma_framework,
      child_block_interval: child_block_interval,
      height: height,
      opts: opts
    }

    {:ok, state}
  end

  @doc """
  The purpose here is to check if blocks need to be resubmitted because
     they were not accepted (LOW GAS) or whatever other reason!
  """
  def handle_info({:internal_event_bus, :ethereum_new_height, new_height}, state) do
    spawn(fn -> submit(new_height, state) end)
    {:noreply, %{state | height: new_height}}
  end

  @doc """
  The purpose here is to check if blocks need to be resubmitted because
     they were not accepted (LOW GAS) or whatever other reason!
  """
  def handle_cast(:submit, state) do
    spawn(fn -> submit(state.height, state) end)
    {:noreply, state}
  end

  defp submit(height, state) do
    next_child_block = External.next_child_block(state.plasma_framework, state.opts)
    mined_child_block = Core.mined(next_child_block, state.child_block_interval)
    integration_fun = External.submit_block(state.vault, state.plasma_framework)
    {:ok, _} = PlasmaBlock.get_all_and_submit(height, mined_child_block, integration_fun)
    :ok
  end
end
