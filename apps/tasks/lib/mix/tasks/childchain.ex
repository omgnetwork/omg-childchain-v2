defmodule Mix.Tasks.Childchain.Start do
  @shortdoc "Start the childchain server."
  @moduledoc false
  use Mix.Task

  alias Engine.Configuration
  alias Engine.ReleaseTasks.Contract
  alias Mix.Tasks.App.Start

  def run(args) do
    config = Contract.load([ethereumex: [url: Configuration.url()]], system_adapter: Mix.Tasks.Childchain.Start)
    :ok = Application.put_all_env(config)
    Start.run(args)
  end

  def get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK") do
    Configuration.plasma_framework()
  end

  def get_env("AUTHORITY_ADDRESS") do
    Configuration.authority_address()
  end

  def get_env("TX_HASH_CONTRACT") do
    Configuration.tx_hash_contract()
  end

  def get_env("ETHEREUM_RPC_URL") do
    Configuration.url()
  end
end
