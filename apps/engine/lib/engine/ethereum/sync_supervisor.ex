defmodule Engine.Ethereum.SyncSupervisor do
  @moduledoc """
   Ethereum listeners top level supervisor.
  """
  use Supervisor
  require Logger

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{__MODULE__}")

    Supervisor.init([], opts)
  end
end
