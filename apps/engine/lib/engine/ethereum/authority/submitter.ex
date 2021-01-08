defmodule Engine.Ethereum.Authority.Submitter do
  @moduledoc """
  Periodic block submitter.
  """

  alias Engine.DB.Block
  alias Engine.Ethereum.Authority.Submitter.AlarmHandler
  alias Engine.Ethereum.Authority.Submitter.Core
  alias Engine.Ethereum.Authority.Submitter.External

  require Logger

  defstruct [
    :plasma_framework,
    :child_block_interval,
    :height,
    :enterprise,
    :db_connection_lost,
    :ethereum_connection_error,
    :gas_integration_fallback_order,
    :opts
  ]

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(init_arg) do
    name = Keyword.get(init_arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  def init(init_arg) do
    enterprise = Keyword.fetch!(init_arg, :enterprise)
    plasma_framework = Keyword.fetch!(init_arg, :plasma_framework)
    child_block_interval = Keyword.fetch!(init_arg, :child_block_interval)
    gas_integration_fallback_order = Keyword.fetch!(init_arg, :gas_integration_fallback_order)
    opts = Keyword.fetch!(init_arg, :opts)
    alarm_handler = Keyword.get(init_arg, :alarm_handler, AlarmHandler)
    sasl_alarm_handler = Keyword.get(init_arg, :sasl_alarm_handler, :alarm_handler)
    :ok = subscribe_to_alarm(sasl_alarm_handler, alarm_handler, __MODULE__)
    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    state = %__MODULE__{
      plasma_framework: plasma_framework,
      child_block_interval: child_block_interval,
      enterprise: enterprise,
      gas_integration_fallback_order: gas_integration_fallback_order,
      db_connection_lost: false,
      ethereum_connection_error: false,
      opts: opts
    }

    {:ok, state}
  end

  def handle_info({:internal_event_bus, :ethereum_new_height, new_height}, state) do
    new_state = %{state | height: new_height}

    case {new_state.db_connection_lost, new_state.ethereum_connection_error} do
      {false, false} -> submit(new_height, new_state)
      _ -> :ok
    end

    {:noreply, new_state}
  end

  def handle_cast({:set_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | db_connection_lost: true}}
  end

  def handle_cast({:clear_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | db_connection_lost: false}}
  end

  def handle_cast({:set_alarm, :ethereum_connection_error}, state) do
    {:noreply, %{state | ethereum_connection_error: true}}
  end

  def handle_cast({:clear_alarm, :ethereum_connection_error}, state) do
    {:noreply, %{state | ethereum_connection_error: false}}
  end

  # This is the submitting part of block. At this point, a blocks are already formed.
  # We compared formed blocks with blocks already accepted and persisted to Ethereum.
  # Any kind of conflicts are resolved in the PG transaction, nonce of the Ethereum transaction
  # and the consesus mechanism of Ethereum.
  defp submit(height, state) do
    _ = Logger.debug("Checking for new blocks")
    next_child_block = External.next_child_block(state.plasma_framework, state.opts)
    mined_child_block = Core.mined(next_child_block, state.child_block_interval)
    submit_fn = External.submit_block(state.plasma_framework, state.enterprise, state.opts)
    gas_fun = External.gas(state.gas_integration_fallback_order)
    {:ok, _} = Block.get_all_and_submit(height, mined_child_block, submit_fn, gas_fun)
    :ok
  end

  defp subscribe_to_alarm(sasl_alarm_handler, handler, consumer) do
    case Enum.member?(:gen_event.which_handlers(sasl_alarm_handler), handler) do
      true -> :ok
      _ -> :gen_event.add_handler(sasl_alarm_handler, handler, consumer: consumer)
    end
  end
end
