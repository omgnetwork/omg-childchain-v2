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
    _ = Logger.debug("Retrieved next child block number #{block_number}.")
    block_number
  end

  def gas(gas_integration_fallback_order) do
    fn ->
      get_gas(gas_integration_fallback_order)
    end
  end

  @doc """
    This is the point where we integrate with SubmitBlock.
    Default integration signature:
    SubmitBlock.submit_block(block_root, nonce, gas_price, contract, opts)

  """
  @spec submit_block(String.t(), 0 | 1, Keyword.t()) :: function()
  def submit_block(plasma_framework, enteprise, opts) do
    {module, opts1} = Keyword.pop!(opts, :module)
    {function, opts2} = Keyword.pop!(opts1, :function)
    external_opts = external_opts(enteprise, opts2)
    contract = plasma_framework

    fn block_root, nonce, gas_price ->
      IO.inspect apply(module, function, [block_root, nonce, gas_price, contract, external_opts]), label: "output"
      :ok
    end
  end

  @spec external_opts(0 | 1, Keyword.t()) :: Keyword.t()
  defp external_opts(0, opts) do
    # even though we merge opts, ethereumex takes only :url
    private_key = System.get_env("PRIVATE_KEY")
    [private_key: private_key] ++ opts
  end

  defp external_opts(1, opts) do
    vault_token = System.get_env("VAULT_TOKEN")
    wallet_name = System.get_env("WALLET_NAME")
    authority_address = System.get_env("AUTHORITY_ADDRESS")
    [vault_token: vault_token, wallet_name: wallet_name, authority_address: authority_address] ++ opts
  end

  defp call(plasma_framework, signature, args, opts) do
    Rpc.call_contract(plasma_framework, signature, args, opts)
  end

  defp get_gas(_, result) when is_struct(result) do
    result
  end

  defp get_gas(integrations, result) do
    _ = Logger.error("Got bad gas response: #{inspect(result)}. Continue to fallback: #{inspect(integrations)}")
    get_gas(integrations)
  end

  # I think this needs to be rescued, let's see.
  defp get_gas([integration | integrations]) do
    get_gas(integrations, apply(Gas, :get, [integration]))
  end
end
