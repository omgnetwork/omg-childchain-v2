defmodule Engine.Configuration do
  @moduledoc """
    Configuration access interface
  """
  @app :engine

  def child_block_interval() do
    Application.fetch_env!(@app, :child_block_interval)
  end

  def finality_margin() do
    Application.fetch_env!(@app, :finality_margin)
  end

  def contract_deployment_height() do
    Application.fetch_env!(@app, :contract_deployment_height)
  end

  def metrics_collection_interval() do
    60_000
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

  def db_fetch_retry_interval() do
    Application.fetch_env!(@app, :db_fetch_retry_interval)
  end

  @doc """
  Prepares options Keyword for the FeeServer process
  """
  @spec fee_server_opts() :: no_return | Keyword.t()
  def fee_server_opts() do
    fee_opts = Application.fetch_env!(@app, Engine.Fees)

    fee_server_opts = [
      fee_fetcher_check_interval_ms: Keyword.fetch!(fee_opts, :fee_fetcher_check_interval_ms),
      fee_buffer_duration_ms: Keyword.fetch!(fee_opts, :fee_buffer_duration_ms)
    ]

    Keyword.merge(fee_server_opts, fee_fetcher_opts: fee_opts)
  end
end
