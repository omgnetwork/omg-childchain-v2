defmodule Engine.Ethereum.Authority.Submitter.Core do
  @moduledoc """
    Submission + Ethereum logic 
  """

  @doc """
    Plasma contracts give us the next mined plasma block number, but we're insterested in the 
    current block number.
    The last mined block is the difference between the next childblock minus the interval.
  """
  @spec mined(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def mined(next_child_block, child_block_interval) do
    next_child_block - child_block_interval
  end
end
