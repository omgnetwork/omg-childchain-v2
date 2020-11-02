defmodule Mix.Tasks.Childchain.Start do
  @shortdoc "Start the childchain server."
  @moduledoc false
  use Mix.Task

  alias Engine.Configuration
  alias Engine.ReleaseTasks.Contract
  alias Mix.Tasks.App.Start

  @doc """
  ## Command line options
      * `--force` - forces compilation regardless of compilation times
      * `--temporary` - starts the application as temporary
      * `--permanent` - starts the application as permanent
      * `--preload-modules` - preloads all modules defined in applications
      * `--no-archives-check` - does not check archives
      * `--no-compile` - does not compile even if files require compilation
      * `--no-deps-check` - does not check dependencies
      * `--no-elixir-version-check` - does not check Elixir version
      * `--no-start` - does not actually start applications, only compiles and loads code
      * `--no-validate-compile-env` - does not validate the application compile environment
  https://github.com/elixir-lang/elixir/blob/v1.10.3/lib/mix/lib/mix/tasks/app.start.ex
  """
  def run(args) do
    Mix.Task.run("compile")
    config = Contract.load([ethereumex: [url: Configuration.rpc_url()]], system_adapter: Mix.Tasks.Childchain.Start)
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
    Configuration.rpc_url()
  end
end
