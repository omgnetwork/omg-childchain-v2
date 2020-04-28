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

  def root_deployment_height() do
    Application.fetch_env(@app, :root_deployment_height)
  end

  def metrics_collection_interval() do
    60_000
  end

  def coordinator_eth_height_check_interval_ms() do
    8000
  end

  def ethereum_events_check_interval_ms() do
    8000
  end

  def ethereum_stalled_sync_threshold_ms() do
    60_000
  end

  def contracts() do
    [
      Application.get_env(@app, :plasma_framework),
      Application.get_env(@app, :erc20_vault),
      Application.get_env(@app, :eth_vault),
      Application.get_env(@app, :payment_exit_game)
    ]
  end

  def url() do
    Application.get_env(@app, :rpc_url)
  end
end
