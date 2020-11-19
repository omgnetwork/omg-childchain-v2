defmodule Engine.BlockForming.PrepareForSubmission.Core do
  @moduledoc """
    Preparing block for submission logic
  """

  def should_finalize_block?(state, eth_height, last_formed_block_at_height) do
    # e.g. if we're at 15th Ethereum block now, last formed was at 14th, we're finalizing a child chain block on every
    # single Ethereum block (`block_submit_every_nth` == 1), then we could form a new block (`it_is_time` is `true`)
    eth_height - last_formed_block_at_height >= state.block_submit_every_nth
  end
end
