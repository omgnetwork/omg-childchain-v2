defmodule Engine.BlockForming.PrepareForSubmission do
  @moduledoc """
  For blocks in finalizing state:
  - attaches fee transactions
  - calculates merkle root hash
  - changes state to :pending_submission
  """
  use GenServer

  alias Engine.BlockForming.PrepareForSubmission.AlarmHandler
  alias Engine.DB.Block

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    interval = Keyword.fetch!(args, :prepare_block_for_submission_interval_ms)
    blocks_module = Keyword.get(args, :block_module, Block)

    alarm_handler = Keyword.get(args, :alarm_handler, AlarmHandler)
    sasl_alarm_handler = Keyword.get(args, :sasl_alarm_handler, :alarm_handler)
    :ok = subscribe_to_alarm(sasl_alarm_handler, alarm_handler, self())

    {:ok, %{interval: interval, blocks_module: blocks_module, connection_alarm_raised: false}, interval}
  end

  def handle_info(:timeout, %{connection_alarm_raised: false} = state) do
    _ = Logger.debug("Preparing blocks for submission")
    {:ok, %{blocks_for_submission: blocks}} = state.blocks_module.prepare_for_submission()
    _ = Logger.info("Prepared #{inspect(Enum.count(blocks))} blocks for submision")
    {:noreply, state, state.interval}
  end

  def handle_info(:timeout, %{connection_alarm_raised: true} = state) do
    _ = Logger.debug("Skipping preparing blocks for submission - no database connection")
    {:noreply, state, state.interval}
  end

  def handle_cast({:set_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | connection_alarm_raised: true}, state.interval}
  end

  def handle_cast({:clear_alarm, :db_connection_lost}, state) do
    {:noreply, %{state | connection_alarm_raised: false}, state.interval}
  end

  defp subscribe_to_alarm(sasl_alarm_handler, handler, consumer) do
    case Enum.member?(:gen_event.which_handlers(sasl_alarm_handler), handler) do
      true -> :ok
      _ -> :gen_event.add_handler(sasl_alarm_handler, handler, consumer: consumer)
    end
  end
end
