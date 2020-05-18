defmodule Engine.Ethereum.Authority.Submitter.External do
  @moduledoc false

  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Rpc

  require Logger

  @type option :: {:url, String.t()}
  @doc """
  Next child block with the interval of Config.child_block_interval() - normally that's 1000, 2000, 3000,...
  NOT YET MINED.
  """
  def next_child_block(plasma_framework, opts) do
    signature = "nextChildBlock()"
    {:ok, data} = call(plasma_framework, signature, [], opts)
    %{"block_number" => block_number} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved next child block number #{block_number}.")
    block_number
  end

  defp call(plasma_framework, signature, args, opts) do
    Rpc.call_contract(plasma_framework, signature, args, opts)
  end
end
