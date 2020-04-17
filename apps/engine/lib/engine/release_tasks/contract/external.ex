defmodule Engine.ReleaseTasks.Contract.External do
  @moduledoc false

  alias DBConnection.Backoff
  alias Engine.Encoding
  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Rpc

  require Logger

  @type option :: {:url, String.t()}

  def exit_game_contract_address(plasma_framework, tx_type, opts) do
    signature = "exitGames(uint256)"
    {:ok, data} = call(plasma_framework, signature, [tx_type], opts)
    %{"exit_game_address" => exit_game_address} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved exit game address #{exit_game_address}.")
    exit_game_address
  end

  def vault(plasma_framework, id, opts) do
    signature = "vaults(uint256)"
    {:ok, data} = call(plasma_framework, signature, [id], opts)
    %{"vault_address" => vault_address} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved vault address for #{id} #{vault_address}.")
    vault_address
  end

  def min_exit_period(plasma_framework, opts) do
    signature = "minExitPeriod()"
    {:ok, data} = call(plasma_framework, signature, [], opts)
    %{"min_exit_period" => min_exit_period} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved min exit period #{min_exit_period}.")
    min_exit_period
  end

  def contract_semver(plasma_framework, opts) do
    signature = "getVersion()"
    {:ok, data} = call(plasma_framework, signature, [], opts)
    %{"version" => version} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved version #{version}.")
    version
  end

  def child_block_interval(plasma_framework, opts) do
    signature = "childBlockInterval()"
    {:ok, data} = call(plasma_framework, signature, [], opts)
    %{"child_block_interval" => child_block_interval} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved child block interval #{child_block_interval}.")
    child_block_interval
  end

  def root_deployment_height(plasma_framework, tx_hash, opts) do
    {:ok, %{"contractAddress" => ^plasma_framework, "blockNumber" => height}} = Rpc.transaction_receipt(tx_hash, opts)
    Encoding.int_from_hex(height)
  end

  defp call(plasma_framework, signature, args, opts) do
    case Rpc.call_contract(plasma_framework, signature, args, opts) do
      {:ok, _data} = result ->
        result

      reason ->
        # if ethereum client isn't ready yet, we wait until it comes back
        {timeout, backoff} = Backoff.backoff(Process.get(:backoff))
        %Backoff{} = Process.put(:backoff, backoff)
        rpc_url = Keyword.get(opts, :url) || Application.get_env(:ethereumex, :url)

        _ =
          Logger.error(
            "Ethereum client not available #{rpc_url}. Getting #{inspect(reason)}. Will wait for #{timeout} ms."
          )

        :ok = Process.sleep(timeout)
        call(plasma_framework, signature, args, opts)
    end
  end
end
