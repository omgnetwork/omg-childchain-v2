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
    Application.get_env(@app, :ethereum_events_check_interval_ms)
  end

  def ethereum_stalled_sync_threshold_ms() do
    60_000
  end

  @spec contracts() :: list(String.t())
  def contracts() do
    [
      Application.get_env(@app, :plasma_framework),
      Application.get_env(@app, :erc20_vault),
      Application.get_env(@app, :eth_vault),
      Application.get_env(@app, :payment_exit_game)
    ]
  end

  @spec eth_vault() :: String.t()
  def eth_vault() do
    Application.get_env(@app, :eth_vault)
  end

  @spec url() :: String.t()
  def url() do
    Application.get_env(@app, :url)
  end

  @spec plasma_framework() :: String.t()
  def plasma_framework() do
    Application.get_env(@app, :plasma_framework)
  end

  @spec authority_address() :: String.t()
  def authority_address() do
    Application.get_env(@app, :authority_address)
  end

  @spec tx_hash_contract() :: String.t()
  def tx_hash_contract() do
    Application.get_env(@app, :tx_hash_contract)
  end

  @doc """
  Prepares options Keyword for the FeeServer process
  """
  @spec fee_server_opts() :: no_return | Keyword.t()
  def fee_server_opts() do
    fee_server_opts = [
      fee_adapter_check_interval_ms: Application.fetch_env!(@app, :fee_adapter_check_interval_ms),
      fee_buffer_duration_ms: Application.fetch_env!(@app, :fee_buffer_duration_ms)
    ]

    {adapter, opts: adapter_opts} = fee_adapter_opts()

    Keyword.merge(fee_server_opts, fee_adapter: adapter, fee_adapter_opts: adapter_opts)
  end

  @spec fee_adapter_opts() :: no_return | tuple()
  defp fee_adapter_opts() do
    Application.fetch_env!(@app, :fee_adapter)
  end
end
