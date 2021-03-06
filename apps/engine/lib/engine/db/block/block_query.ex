defmodule Engine.DB.Block.BlockQuery do
  @moduledoc """
  Queries related to transactions
  """

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block

  @doc """
  Query all transactions that have not been formed into a block.
  """
  def select_forming_block_for_update() do
    forming = Block.state_forming()
    from(block in Block, where: block.state == ^forming, lock: "FOR UPDATE")
  end

  @doc """
  Returns the biggest nonce
  """
  def select_max_nonce(), do: from(block in Block, select: max(block.nonce))

  @doc """
  Returns all blocks awaiting submission
  """
  def get_all_for_submission(new_height, mined_child_block) do
    pending_submission = Block.state_pending_submission()

    # block awaiting submission is either:
    # - already submitted but not mined block
    # - block that is not submitted yet and is in state pending_submission
    from(b in Block,
      where:
        (b.submitted_at_ethereum_height < ^new_height or
           (is_nil(b.submitted_at_ethereum_height) and b.state == ^pending_submission)) and
          b.blknum > ^mined_child_block,
      order_by: [asc: :nonce]
    )
  end

  @doc """
  Returns all finalizing blocks
  """
  def select_finalizing_blocks() do
    finalizing = Block.state_finalizing()
    from(block in Block, where: block.state == ^finalizing)
  end

  @doc """
  Returns the largest rootchain height at which a childchain block was formed
  """
  def get_last_formed_block_eth_height() do
    from(b in Block, select: max(b.formed_at_ethereum_height))
  end
end
