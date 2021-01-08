defmodule Engine.BlockFormation.PrepareForSubmission do
  @moduledoc """
  For blocks in finalizing state:
  - attaches fee transactions
  - calculates merkle root hash
  - changes state to :pending_submission
  """
  use GenServer

  alias Engine.BlockFormation.PrepareForSubmission.AlarmHandler
  alias Engine.BlockFormation.PrepareForSubmission.Core
  alias Engine.DB.Block

  require Logger

  defstruct [:block_submit_every_nth, :block_module, :db_connection_lost]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(init_arg) do
    block_submit_every_nth = Keyword.fetch!(init_arg, :block_submit_every_nth)

    alarm_handler = Keyword.get(init_arg, :alarm_handler, AlarmHandler)
    sasl_alarm_handler = Keyword.get(init_arg, :sasl_alarm_handler, :alarm_handler)
    :ok = subscribe_to_alarm(sasl_alarm_handler, alarm_handler, __MODULE__)
    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    {:ok,
     %__MODULE__{
       block_submit_every_nth: block_submit_every_nth,
       db_connection_lost: false
     }}
  end

  def handle_info({:internal_event_bus, :ethereum_new_height, new_height}, %{db_connection_lost: false} = state) do
    _ = Logger.debug("Preparing blocks for submission")

    last_formed_block_at_height =
      case Block.get_last_formed_block_eth_height() do
        nil -> 0
        height -> height
      end

    :ok =
      case Core.should_finalize_block?(new_height, last_formed_block_at_height, state.block_submit_every_nth) do
        true -> Block.finalize_forming_block()
        false -> :ok
      end

    {:ok, %{blocks_for_submission: blocks}} = Block.prepare_for_submission(new_height)
    _ = Logger.info("Prepared #{inspect(Enum.count(blocks))} blocks for submision")
    {:noreply, state}
  end

  def handle_info(_, %{db_connection_lost: true} = state) do
    _ = Logger.debug("Skipping preparing blocks for submission - no database connection")
    {:noreply, state}
  end

  def handle_cast({:set_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | db_connection_lost: true}}
  end

  def handle_cast({:clear_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | db_connection_lost: false}}
  end

  defp subscribe_to_alarm(sasl_alarm_handler, handler, consumer) do
    case Enum.member?(:gen_event.which_handlers(sasl_alarm_handler), handler) do
      true -> :ok
      _ -> :gen_event.add_handler(sasl_alarm_handler, handler, consumer: consumer)
    end
  end
end
