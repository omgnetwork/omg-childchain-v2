defmodule Engine.ReleaseTasks.SetContract do
  @moduledoc false
  @behaviour Config.Provider

  alias DBConnection.Backoff
  alias Engine.Encoding
  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Rpc
  require Logger

  @ether_vault_id 1
  @erc20_vault_id 2

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load(args)
    plasma_framework = get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")
    tx_hash = get_env("TXHASH_CONTRACT")

    [
      payment_exit_game,
      eth_vault,
      erc20_vault,
      min_exit_period_seconds,
      contract_semver,
      child_block_interval,
      root_deployment_height
    ] = get_external_data(plasma_framework, tx_hash)

    Config.Reader.merge(config,
      engine: [
        plasma_framework: plasma_framework,
        eth_vault: eth_vault,
        erc20_vault: erc20_vault,
        payment_exit_game: payment_exit_game,
        min_exit_period_seconds: min_exit_period_seconds,
        contract_semver: contract_semver,
        child_block_interval: child_block_interval,
        root_deployment_height: root_deployment_height
      ]
    )
  end

  defp get_external_data(plasma_framework, tx_hash) do
    min_exit_period_seconds = get_min_exit_period(plasma_framework)
    payment_exit_game = plasma_framework |> exit_game_contract_address(ExPlasma.payment_v1()) |> Encoding.to_hex()
    eth_vault = plasma_framework |> get_vault(@ether_vault_id) |> Encoding.to_hex()
    erc20_vault = plasma_framework |> get_vault(@erc20_vault_id) |> Encoding.to_hex()
    contract_semver = get_contract_semver(plasma_framework)
    child_block_interval = get_child_block_interval(plasma_framework)
    root_deployment_height = get_root_deployment_height(plasma_framework, tx_hash)

    [
      payment_exit_game,
      eth_vault,
      erc20_vault,
      min_exit_period_seconds,
      contract_semver,
      child_block_interval,
      root_deployment_height
    ]
  end

  defp get_min_exit_period(plasma_framework) do
    signature = "minExitPeriod()"
    {:ok, data} = call(plasma_framework, signature, [])
    %{"min_exit_period" => min_exit_period} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved min exit period #{min_exit_period}.")
    min_exit_period
  end

  defp exit_game_contract_address(plasma_framework, tx_type) do
    signature = "exitGames(uint256)"
    {:ok, data} = call(plasma_framework, signature, [tx_type])
    %{"exit_game_address" => exit_game_address} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved exit game address #{exit_game_address}.")
    exit_game_address
  end

  defp get_vault(plasma_framework, id) do
    signature = "vaults(uint256)"
    {:ok, data} = call(plasma_framework, signature, [id])
    %{"vault_address" => vault_address} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved vault address for #{id} #{vault_address}.")
    vault_address
  end

  defp get_contract_semver(plasma_framework) do
    signature = "getVersion()"
    {:ok, data} = call(plasma_framework, signature, [])
    %{"version" => version} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved version #{version}.")
    version
  end

  defp get_child_block_interval(plasma_framework) do
    signature = "childBlockInterval()"
    {:ok, data} = call(plasma_framework, signature, [])
    %{"child_block_interval" => child_block_interval} = Abi.decode_function(data, signature)
    _ = Logger.info("Retrieved child block interval #{child_block_interval}.")
    child_block_interval
  end

  defp get_root_deployment_height(plasma_framework, tx_hash) do
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
        Process.sleep(1000)
        call(plasma_framework, signature, args, retries_left - 1)

      {:error, :econnrefused} = reason ->
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

  defp get_env(key) do
    Process.get(:system_adapter).get_env(key)
  end

  defp rpc_api() do
    Process.get(:rpc_api)
  end

  defp on_load(args) do
    rpc_api = Keyword.get(args, :rpc_api, Rpc)
    adapter = Keyword.get(args, :system_adapter, System)
    {backoff, _opts} = Keyword.split(args, [:backoff_min, :backoff_max, :type])
    backoff_state = Backoff.new(backoff)
    nil = Process.put(:rpc_api, rpc_api)
    nil = Process.put(:system_adapter, adapter)
    nil = Process.put(:backoff, backoff_state)
    rpc_url = get_env("ETHEREUM_RPC_URL")

    case rpc_url do
      nil ->
        :ok

      _ ->
        :ok = Application.put_env(:ethereumex, :url, rpc_url, persistent: true)
    end

    {:ok, _} = Application.ensure_all_started(:logger)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, _} = Application.ensure_all_started(:telemetry)
  end
end
