defmodule Engine.Ethereum.Authority.Submitter.Core do
  @moduledoc """
    All the difficulties here.
  """
  @spec mined(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def mined(next_child_block, child_block_interval) do
    next_child_block - child_block_interval
  end

  # the height is here so that we can compare 
  # 
  def get_all_and_submit(new_height, mined_child_block) do
  end
end
