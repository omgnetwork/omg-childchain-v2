defmodule Engine.Supervisor do
  @moduledoc """
   Engine top level supervisor is supervising FeeServer and block Submitter.

  """
  use Supervisor

  alias Engine.Configuration
  alias Engine.Ethereum.Authority.Submitter
  alias Engine.Fee.Server, as: FeeServer

  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    # we did not fetch fees yet
    FeeServer.raise_fee_source_alarm()

    fee_server_opts = Configuration.fee_server_opts()

    enterprise = apply(SubmitBlock, :enterprise, [])

    url =
      case enterprise do
        0 -> Configuration.rpc_url()
        1 -> Configuration.vault_url()
      end

    submitter_opts = [
      plasma_framework: Configuration.plasma_framework(),
      child_block_interval: Configuration.child_block_interval(),
      opts: [module: SubmitBlock, function: :submit_block, url: url, http_request_options: []],
      gas_integration_fallback_order: [
        Gas.Integration.Etherscan,
        Gas.Integration.GasPriceOracle,
        Gas.Integration.Pulse,
        Gas.Integration.Web3Api
      ],
      enterprise: enterprise
    ]

    children = [
      {FeeServer, fee_server_opts},
      {Submitter, submitter_opts}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
