defmodule Engine.Supervisor do
  @moduledoc """
   Engine top level supervisor is supervising FeeServer.
  """
  use Supervisor

  alias Engine.Configuration
  alias Engine.Fee.Server, as: FeeServer
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    fee_server_opts = Configuration.fee_server_opts()

    children = [
      # {FeeServer, fee_server_opts}
    ]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
