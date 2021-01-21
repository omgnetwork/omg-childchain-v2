defmodule Engine.Supervisor do
  @moduledoc """
   Engine top level supervisor is supervising FeeServer and block Submitter.

  """
  use Supervisor

  alias Engine.BlockFormation.PrepareForSubmission
  alias Engine.Configuration
  alias Engine.Ethereum.Authority.Submitter
  alias Engine.Fee.Server, as: FeeServer

  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    enterprise = apply(SubmitBlock, :enterprise, [])

    vault_url =
      case enterprise do
        0 -> nil
        1 -> Configuration.vault_url()
      end

    rpc_url = Configuration.rpc_url()

    integration_opts = [
      module: SubmitBlock,
      function: :submit_block,
      url: rpc_url,
      vault_url: vault_url,
      http_request_options: []
    ]

    submitter_opts = [
      plasma_framework: Configuration.plasma_framework(),
      child_block_interval: Configuration.child_block_interval(),
      opts: integration_opts,
      gas_integration_fallback_order: [
        Gas.Integration.Etherscan,
        Gas.Integration.GasPriceOracle,
        Gas.Integration.Pulse,
        Gas.Integration.Web3Api
      ],
      enterprise: enterprise
    ]

    prepare_block_for_submission_opts = [
      block_submit_every_nth: Configuration.block_submit_every_nth()
    ]

    children =
      fee_server() ++
        [
          {Submitter, submitter_opts},
          {PrepareForSubmission, prepare_block_for_submission_opts}
        ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end

  defp fee_server() do
    # we did not fetch fees yet
    FeeServer.raise_no_fees_alarm()

    fee_server_opts = Configuration.fee_server_opts()
    [{FeeServer, fee_server_opts}]
  end
end
