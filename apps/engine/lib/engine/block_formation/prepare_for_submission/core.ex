defmodule Engine.BlockFormation.PrepareForSubmission.Core do
  @moduledoc """
    Preparing block for submission logic
  """

  @spec should_finalize_block?(pos_integer(), non_neg_integer(), pos_integer()) :: boolean()
  def should_finalize_block?(eth_height, last_formed_block_at_height, block_submit_every_nth) do
    # e.g. if we're at 15th Ethereum block now, last formed was at 14th, we're finalizing a child chain block on every
    # single Ethereum block (`block_submit_every_nth` == 1), then we can form a new block
    eth_height - last_formed_block_at_height >= block_submit_every_nth
  end
end
