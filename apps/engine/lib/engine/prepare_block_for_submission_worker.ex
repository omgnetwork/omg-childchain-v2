defmodule Engine.PrepareBlockForSubmissionWorker do
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
    interval = Keyword.fetch!(args, :prepare_block_for_submission_interval_ms)
    blocks_module = Keyword.get(args, :block_module, Block)
    {:ok, %{block_preparation_interval: interval, blocks_module: blocks_module}, interval}
  end

  def handle_info(:timeout, state) do
    _ = Logger.debug("Preparing blocks for submission")

    case state.blocks_module.prepare_for_submission() do
      {:ok, %{blocks: blocks}} ->
        _ = Logger.info("Prepared #{inspect(Enum.count(blocks))} blocks for submision")
        {:noreply, state, state.interval}

      {:error, err} ->
        _ = Logger.error("Error when preparing blocks for submission: #{inspect(err)}")
        {:stop, err}
    end
  end
end
