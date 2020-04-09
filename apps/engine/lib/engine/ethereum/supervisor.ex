defmodule Engine.Ethereum.Supervisor do
  @moduledoc """
   Etherereum capabilities top level supervisor.
  """
  use Supervisor
  require Logger

  alias Engine.Ethereum.Monitor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    # RootChain.get_root_deployment_height()
    {:ok, contract_deployment_height} = {:ok, 30}

    children = [
      {Monitor,
       [
         alarm: Alarm,
         child_spec: %{
           id: SyncSupervisor,
           start:
             {SyncSupervisor, :start_link,
              [[contract_deployment_height: contract_deployment_height]]},
           restart: :permanent,
           type: :supervisor
         }
       ]}
    ]

    opts = [strategy: :one_for_one]
    _ = Logger.info("Starting #{__MODULE__}")
    Supervisor.init(children, opts)
  end
end
