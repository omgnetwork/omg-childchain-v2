defmodule Engine.BlockForming.PrepareForSubmission do
  @moduledoc """
  For blocks in finalizing state:
  - attaches fee transactions
  - calculates merkle root hash
  - changes state to :pending_submission
  """
  use GenServer

  alias Engine.BlockForming.PrepareForSubmission.AlarmHandler
  alias Engine.BlockForming.PrepareForSubmission.Core
  alias Engine.DB.Block

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    block_submit_every_nth = Keyword.fetch!(args, :block_submit_every_nth)
    block_module = Keyword.get(args, :block_module, Block)

    alarm_handler = Keyword.get(args, :alarm_handler, AlarmHandler)
    sasl_alarm_handler = Keyword.get(args, :sasl_alarm_handler, :alarm_handler)
    :ok = subscribe_to_alarm(sasl_alarm_handler, alarm_handler, self())
    event_bus = Keyword.get(args, :event_bus, Bus)
    :ok = event_bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    {:ok,
     %{
       block_submit_every_nth: block_submit_every_nth,
       block_module: block_module,
       connection_alarm_raised: false
     }}
  end

  def handle_info({:internal_event_bus, :ethereum_new_height, new_height}, %{connection_alarm_raised: false} = state) do
    _ = Logger.debug("Preparing blocks for submission")

    last_formed_block_at_height =
      case Block.get_last_formed_block_eth_height() do
        nil -> 0
        height -> height
      end

    :ok =
      case Core.should_finalize_block?(state, new_height, last_formed_block_at_height) do
        true -> state.block_module.finalize_forming_block()
        false -> :ok
      end

    {:ok, %{blocks_for_submission: blocks}} = state.block_module.prepare_for_submission(new_height)
    _ = Logger.info("Prepared #{inspect(Enum.count(blocks))} blocks for submision")
    {:noreply, state}
  end

  def handle_info(_, %{connection_alarm_raised: true} = state) do
    _ = Logger.debug("Skipping preparing blocks for submission - no database connection")
    {:noreply, state}
  end

  def handle_cast({:set_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | connection_alarm_raised: true}}
  end

  def handle_cast({:clear_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | connection_alarm_raised: false}}
  end

  defp subscribe_to_alarm(sasl_alarm_handler, handler, consumer) do
    case Enum.member?(:gen_event.which_handlers(sasl_alarm_handler), handler) do
      true -> :ok
      _ -> :gen_event.add_handler(sasl_alarm_handler, handler, consumer: consumer)
    end
  end
end
