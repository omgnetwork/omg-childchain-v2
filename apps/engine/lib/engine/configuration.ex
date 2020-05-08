defmodule Engine.Configuration do
  @moduledoc """
    Configuration access interface
  """
  @app :engine

  @spec ethereumex_url() :: String.t()
  def ethereumex_url() do
    Application.fetch_env!(:ethereumex, :url)
  end

  def deposit_finality_margin() do
    10
  end

  def contract_deployment_height() do
    Application.fetch_env!(:engine, :contract_deployment_height)
  end

  def metrics_collection_interval() do
    60_000
  end

  def coordinator_eth_height_check_interval_ms() do
    8000
  end

  def ethereum_events_check_interval_ms() do
    Application.fetch_env!(@app, :ethereum_events_check_interval_ms)
  end

  def ethereum_stalled_sync_threshold_ms() do
    60_000
  end

  @spec contracts() :: list(String.t())
  def contracts() do
    [
      Application.fetch_env!(@app, :plasma_framework),
      Application.fetch_env!(@app, :erc20_vault),
      Application.fetch_env!(@app, :eth_vault),
      Application.fetch_env!(@app, :payment_exit_game)
    ]
  end

  @spec eth_vault() :: String.t()
  def eth_vault() do
    Application.fetch_env!(@app, :eth_vault)
  end

  @spec url() :: String.t()
  def url() do
    Application.fetch_env!(@app, :url)
  end

  @spec plasma_framework() :: String.t()
  def plasma_framework() do
    Application.fetch_env!(@app, :plasma_framework)
  end

  @spec authority_address() :: String.t()
  def authority_address() do
    Application.fetch_env!(@app, :authority_address)
  end

  @spec tx_hash_contract() :: String.t()
  def tx_hash_contract() do
    Application.fetch_env!(@app, :tx_hash_contract)
  end

  def scheduler_interval() do
    Application.fetch_env!(@app, Engine.Feefeed.Rules.Scheduler)[:interval]
  end

  def source_config() do
    @app
    |> Application.fetch_env!(Engine.Feefeed.Rules.Source)
    |> Enum.into(%{})
    |> Map.merge(%{vsn: Application.spec(:engine, :vsn)})
  end

  def db_fetch_retry_interval() do
    Application.fetch_env!(@app, :db_fetch_retry_interval)
  end
end
