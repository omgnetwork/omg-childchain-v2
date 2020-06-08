defmodule Engine.Ethereum.Authority.Submitter.External do
  @moduledoc """
    Everything outside.
  """

  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Rpc

  require Logger

  @type option :: {:url, String.t()}
  @doc """
  Next child block with the interval of Config.child_block_interval(). 
  Normally that's 1000, 2000, 3000,...
  NOT YET MINED!
  To get the last mined block:
  last_mined = next_child_block/2 - child_block_interval/0
  """
  @spec next_child_block(String.t(), Keyword.t()) :: non_neg_integer()
  def next_child_block(plasma_framework, opts) do
    signature = "nextChildBlock()"
    {:ok, data} = call(plasma_framework, signature, [], opts)
    %{"block_number" => block_number} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved next child block number #{block_number}.")
    block_number
  end

  @spec submit_block(String.t(), String.t(), binary(), pos_integer(), pos_integer()) :: :ok
  def submit_block(plasma_framework, url, block_root, nonce, gas) do
    body = %{"block_root" => block_root, "gas" => gas, "nonce" => nonce}
    {:ok, %HTTPoison.Response{status_code: 200}} = HTTPoison.post(url, body)
    :ok
  end

  defp call(plasma_framework, signature, args, opts) do
    Rpc.call_contract(plasma_framework, signature, args, opts)
  end
end
