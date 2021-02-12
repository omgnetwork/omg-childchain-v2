defmodule Engine.Configuration do
  @moduledoc """
    Configuration access interface
  """

  alias ExPlasma.Encoding

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

  @spec erc20_vault() :: String.t()
  def erc20_vault() do
    Application.fetch_env!(@app, :erc20_vault)
  end

  @spec rpc_url() :: String.t()
  def rpc_url() do
    Application.fetch_env!(@app, :rpc_url)
  end

  @spec payment_exit_game() :: String.t()
  def payment_exit_game() do
    Application.fetch_env!(@app, :payment_exit_game)
  end

  @spec vault_url() :: String.t() | nil
  def vault_url() do
    Application.get_env(@app, :vault_url)
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

  @spec fee_claimer_address :: <<_::160>>
  def fee_claimer_address() do
    @app
    |> Application.fetch_env!(:fee_claimer_address)
    |> Encoding.to_binary!()
  end

  @doc """
  Prepares options Keyword for the FeeServer process
  """
  @spec fee_server_opts() :: no_return | Keyword.t()
  def fee_server_opts() do
    fee_opts = Application.fetch_env!(@app, Engine.Fee)

    fee_server_opts = [
      fee_fetcher_check_interval_ms: Keyword.fetch!(fee_opts, :fee_fetcher_check_interval_ms),
      fee_buffer_duration_ms: Keyword.fetch!(fee_opts, :fee_buffer_duration_ms)
    ]

    Keyword.merge(fee_server_opts, fee_fetcher_opts: fee_opts)
  end

  def ethereum_network() do
    Application.fetch_env!(@app, :network)
  end

  def contract_semver() do
    Application.fetch_env!(@app, :contract_semver)
  end

  def block_submit_every_nth() do
    Application.fetch_env!(@app, :block_submit_every_nth)
  end
end
