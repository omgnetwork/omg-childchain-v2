defmodule Engine.BlockPreparationWorker do
  @moduledoc """
  For blocks in finalizing state:
  - attaches fee transactions
  - calculates merkle root hash
  - changes state to :pending_submission
  """
  use GenServer

  alias Engine.DB.Block

  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    block_preparation_interval = Keyword.fetch!(args, :block_preparation_interval)
    blocks_module = Keyword.get(args, :block_module, Block)
    {:ok, _tref} = :timer.send_after(block_preparation_interval, :prepare_blocks_for_submission)
    {:ok, %{block_preparation_interval: block_preparation_interval, blocks_module: blocks_module}}
  end

  def handle_info(:prepare_blocks_for_submission, state) do
    _ = Logger.debug("Preparing blocks for submission")

    case state.blocks_module.prepare_for_submission() do
      {:ok, %{blocks: blocks}} ->
        _ = Logger.info("Prepared #{inspect(Enum.count(blocks))} blocks for submision")
        {:ok, _tref} = :timer.send_after(state.block_preparation_interval, :prepare_blocks_for_submission)
        {:noreply, state}

      {:error, err} ->
        _ = Logger.error("Error when preparing blocks for submission: #{inspect(err)}")
        {:stop, err}
    end
  end
end
