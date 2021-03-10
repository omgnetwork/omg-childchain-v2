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
    children = [
      {FeeServer, fee_server_opts()},
      {Submitter, submitter_opts()},
      {PrepareForSubmission, prepare_block_for_submission_opts()}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end

  defp fee_server_opts() do
    # we did not fetch fees yet
    FeeServer.raise_no_fees_alarm()

    Configuration.fee_server_opts()
  end

  defp submitter_opts() do
    enterprise = apply(SubmitBlock, :enterprise, [])

    vault_url =
      case {enterprise, Configuration.vault_url()} do
        {1, nil} -> exit("Vault URL is not set.")
        {1, url} -> url
        _ -> nil
      end

    rpc_url = Configuration.rpc_url()
    ufo = Configuration.ufo()

    integration_opts = [
      module: SubmitBlock,
      function: :submit_block,
      url: rpc_url,
      vault_url: vault_url,
      http_request_options: http_request_options()
    ]

    [
      plasma_framework: Configuration.plasma_framework(),
      child_block_interval: Configuration.child_block_interval(),
      opts: integration_opts,
      gas_integration_fallback_order: [
        Gas.Integration.GasPriceOracle,
        Gas.Integration.Etherscan,
        Gas.Integration.Pulse,
        Gas.Integration.Web3Api
      ],
      ufo: ufo,
      enterprise: enterprise
    ]
  end

  defp prepare_block_for_submission_opts() do
    [
      block_submit_every_nth: Configuration.block_submit_every_nth()
    ]
  end

  defp http_request_options() do
    case System.get_env("INSECURE_VAULT_TLS") do
      "true" -> [hackney: [:insecure]]
      "TRUE" -> [hackney: [:insecure]]
      _ -> []
    end
  end
end
