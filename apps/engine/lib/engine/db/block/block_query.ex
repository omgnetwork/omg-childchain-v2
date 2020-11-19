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
  Returns all blocks in the db
  """
  def get_all(new_height, mined_child_block) do
    from(b in Block,
      where:
        (b.submitted_at_ethereum_height < ^new_height or is_nil(b.submitted_at_ethereum_height)) and
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

  def get_last_formed_block_eth_height() do
    from(b in Block, select: max(b.formed_at_ethereum_height))
  end
end
