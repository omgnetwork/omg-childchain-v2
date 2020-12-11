defmodule Engine.ReleaseTasks.Contract do
  @moduledoc """
  Config providers are hulluva difficult to test since they cross many borders.
  So this contract fetching details provider is split into validators and external calls.
  Uses process dictionary to mock out borders.

  Because of mocks, this needs an integration validation - probably in cabbage. Since it needs Geth and deployed contracts.
  """
  @behaviour Config.Provider

  alias DBConnection.Backoff
  alias Engine.DB.ContractsConfig
  alias Engine.ReleaseTasks.Contract.External
  alias Engine.ReleaseTasks.Contract.Validators
  require Logger

  @ether_vault_id 1
  @erc20_vault_id 2

  def init(args) do
    args
  end

  def load(config, args) do
    _ = on_load(args)

    plasma_framework =
      "CONTRACT_ADDRESS_PLASMA_FRAMEWORK" |> get_env() |> Validators.address!("CONTRACT_ADDRESS_PLASMA_FRAMEWORK")

    authority_address = "AUTHORITY_ADDRESS" |> get_env() |> Validators.address!("AUTHORITY_ADDRESS")
    tx_hash = "TX_HASH_CONTRACT" |> get_env() |> Validators.tx_hash!("TX_HASH_CONTRACT")
    default_url = config |> Keyword.fetch!(:ethereumex) |> Keyword.fetch!(:url)
    rpc_url = "ETHEREUM_RPC_URL" |> get_env() |> Validators.url("ETHEREUM_RPC_URL", default_url)

    contracts_config =
      case get_contracts_config_from_db() do
        nil ->
          config = get_config_from_root_chain(plasma_framework, tx_hash, rpc_url)
          :ok = store_contracts_config_in_db(config)
          config

        config ->
          config
      end

    engine_config =
      Keyword.merge(
        [
          rpc_url: rpc_url,
          authority_address: authority_address,
          plasma_framework: plasma_framework
        ],
        contracts_config
      )

    Config.Reader.merge(config, engine: engine_config)
  end

  defp get_contracts_config_from_db() do
    parent = self()

    spawn_link(fn ->
      {:ok, contracts_config, _} = Ecto.Migrator.with_repo(Engine.Repo, &ContractsConfig.get/1)
      Kernel.send(parent, {:done, contracts_config})
    end)

    result_or_wait()
  end

  defp store_contracts_config_in_db(config) do
    params = Enum.into(config, %{})
    {:ok, _, _} = Ecto.Migrator.with_repo(Engine.Repo, fn repo -> ContractsConfig.insert(repo, params) end)
    :ok
  end

  defp get_config_from_root_chain(plasma_framework, tx_hash, rpc_url) do
    payment_exit_game = External.exit_game_contract_address(plasma_framework, ExPlasma.payment_v1(), url: rpc_url)

    eth_vault = External.vault(plasma_framework, @ether_vault_id, url: rpc_url)
    erc20_vault = External.vault(plasma_framework, @erc20_vault_id, url: rpc_url)
    min_exit_period_seconds = External.min_exit_period(plasma_framework, url: rpc_url)
    contract_semver = External.contract_semver(plasma_framework, url: rpc_url)
    child_block_interval = External.child_block_interval(plasma_framework, url: rpc_url)
    contract_deployment_height = External.contract_deployment_height(plasma_framework, tx_hash, url: rpc_url)

    [
      eth_vault: eth_vault,
      erc20_vault: erc20_vault,
      payment_exit_game: payment_exit_game,
      min_exit_period_seconds: min_exit_period_seconds,
      contract_semver: contract_semver,
      child_block_interval: child_block_interval,
      contract_deployment_height: contract_deployment_height
    ]
  end

  defp on_load(args) do
    adapter = Keyword.get(args, :system_adapter, System)
    {backoff, _opts} = Keyword.split(args, [:backoff_min, :backoff_max, :type])
    backoff_state = Backoff.new(backoff)
    nil = Process.put(:system_adapter, adapter)
    nil = Process.put(:backoff, backoff_state)
    {:ok, _} = Application.ensure_all_started(:logger)
    {:ok, _} = Application.ensure_all_started(:ethereumex)
    {:ok, _} = Application.ensure_all_started(:telemetry)
    _ = Application.load(:engine)
  end

  @spec get_env(String.t()) :: String.t()
  defp get_env(key) do
    system_adapter().get_env(key)
  end

  defp system_adapter() do
    Process.get(:system_adapter)
  end

  defp result_or_wait() do
    receive do
      {:EXIT, _, :shutdown} ->
        _ = Logger.error("Can't connect to database. Retrying.")
        get_contracts_config_from_db()

      {:done, contracts_config} ->
        contracts_config
    after
      10_000 ->
        get_contracts_config_from_db()
    end
  end
end
