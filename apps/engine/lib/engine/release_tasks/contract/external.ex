defmodule Engine.ReleaseTasks.Contract.External do
  @moduledoc """
  Hellova mock. Needs integration test!
  """

  alias DBConnection.Backoff
  alias Engine.Encoding
  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Rpc

  require Logger

  def min_exit_period(plasma_framework) do
    signature = "minExitPeriod()"
    {:ok, data} = call(plasma_framework, signature, [])
    %{"min_exit_period" => min_exit_period} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved min exit period #{min_exit_period}.")
    min_exit_period
  end

  def exit_game_contract_address(plasma_framework, tx_type) do
    signature = "exitGames(uint256)"
    {:ok, data} = call(plasma_framework, signature, [tx_type])
    %{"exit_game_address" => exit_game_address} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved exit game address #{exit_game_address}.")
    exit_game_address
  end

  def vault(plasma_framework, id) do
    signature = "vaults(uint256)"
    {:ok, data} = call(plasma_framework, signature, [id])
    %{"vault_address" => vault_address} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved vault address for #{id} #{vault_address}.")
    vault_address
  end

  def contract_semver(plasma_framework) do
    signature = "getVersion()"
    {:ok, data} = call(plasma_framework, signature, [])
    %{"version" => version} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved version #{version}.")
    version
  end

  def child_block_interval(plasma_framework) do
    signature = "childBlockInterval()"
    {:ok, data} = call(plasma_framework, signature, [])
    %{"child_block_interval" => child_block_interval} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved child block interval #{child_block_interval}.")
    child_block_interval
  end

  def root_deployment_height(plasma_framework, tx_hash) do
    {:ok, %{"contractAddress" => ^plasma_framework, "blockNumber" => height}} = rpc_api().transaction_receipt(tx_hash)
    Encoding.int_from_hex(height)
  end

  defp call(plasma_framework, signature, args) do
    retries_left = 3
    call(plasma_framework, signature, args, retries_left)
  end

  defp call(plasma_framework, signature, args, 0) do
    rpc_api().call_contract(plasma_framework, signature, args)
  end

  defp call(plasma_framework, signature, args, retries_left) do
    case rpc_api().call_contract(plasma_framework, signature, args) do
      {:ok, _data} = result ->
        result

      {:error, :closed} ->
        # this clause happens often locally if the geths instances gets hit by RPC calls too hard.
        Process.sleep(1000)
        call(plasma_framework, signature, args, retries_left - 1)

      {:error, :econnrefused} = reason ->
        # if ethereum client isn't ready yet, we wait until it comes back
        {timeout, backoff} = Backoff.backoff(Process.get(:backoff))
        %Backoff{} = Process.put(:backoff, backoff)
        rpc_url = Application.get_env(:ethereumex, :url)

        _ =
          Logger.error(
            "Ethereum client not available #{rpc_url}. Getting #{inspect(reason)}. Will wait for #{timeout} ms."
          )

        :ok = Process.sleep(timeout)
        call(plasma_framework, signature, args, retries_left)
    end
  end

  defp rpc_api() do
    Process.get(:rpc_api, Rpc)
  end
end
