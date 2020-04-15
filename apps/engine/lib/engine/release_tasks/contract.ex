defmodule Engine.ReleaseTasks.Contract do
  @moduledoc """
  Config providers are hulluva difficult to test since they cross many borders.
  So this contract fetching details provider is split into validators and external calls.
  Uses process dictionary to mock out borders.

  Because of mocks, this needs an integration validation - probably in cabbage. Since it needs Geth and deployed contracts.
  """
  @behaviour Config.Provider

  alias DBConnection.Backoff
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
    tx_hash = "TXHASH_CONTRACT" |> get_env() |> Validators.tx_hash!("TXHASH_CONTRACT")

    [
      payment_exit_game,
      eth_vault,
      erc20_vault,
      min_exit_period_seconds,
      contract_semver,
      child_block_interval,
      root_deployment_height
    ] = external_data(plasma_framework, tx_hash)

    Config.Reader.merge(config,
      engine: [
        authority_address: authority_address,
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

  defp external_data(plasma_framework, tx_hash) do
    min_exit_period_seconds = External.min_exit_period(plasma_framework)
    payment_exit_game = External.exit_game_contract_address(plasma_framework, ExPlasma.payment_v1())
    eth_vault = External.vault(plasma_framework, @ether_vault_id)
    erc20_vault = External.vault(plasma_framework, @erc20_vault_id)
    contract_semver = External.contract_semver(plasma_framework)
    child_block_interval = External.child_block_interval(plasma_framework)
    root_deployment_height = External.root_deployment_height(plasma_framework, tx_hash)

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

  defp on_load(args) do
    adapter = Keyword.get(args, :system_adapter, System)
    {backoff, _opts} = Keyword.split(args, [:backoff_min, :backoff_max, :type])
    backoff_state = Backoff.new(backoff)
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

  defp get_env(key) do
    system_adapter().get_env(key)
  end

  defp system_adapter() do
    Process.get(:system_adapter)
  end
end
