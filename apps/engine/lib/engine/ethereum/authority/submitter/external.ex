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

  @doc """
    This is the point where we integrate with Vault.
  """
  @spec submit_block(String.t(), String.t()) :: function()
  def submit_block(plasma_framework, vault) do
    fn block_root, nonce, gas ->
      url = vault <> "/" <> plasma_framework
      body = %{"block_root" => block_root, "gas" => gas, "nonce" => nonce}
      HTTPoison.post(url, body)
    end
    # submit_block(block_root, nonce, gas_price, contract, opts) 
    # vault
    #    opts = [vault_token: vault_token, wallet_name: wallet_name, authority: authority]
    # raw
    #    opts = [private_key_module: System, private_key_function: :get_env, private_key_args: "PRIVATE_KEY"]
    # opts = []

    # fn block_root, nonce, gas_price ->
    #   apply(SubmitBlock, :submit_block, [block_root, nonce, gas_price, plasma_framework])
    # end
  end

  def gas() do
    fn ->
      apply(Gas, :get, [Gas.Integration.Etherscan])
    end
  end

  defp call(plasma_framework, signature, args, opts) do
    Rpc.call_contract(plasma_framework, signature, args, opts)
  end
end
