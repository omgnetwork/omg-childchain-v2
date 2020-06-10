defmodule Engine.Ethereum.Authority.Submitter.Core do
  @moduledoc """
    All the difficulties here.
  """

  @spec mined(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def mined(next_child_block, child_block_interval) do
    next_child_block - child_block_interval
  end
end
