defmodule Bus.Supervisor do
  @moduledoc """
   Bus top level supervisor.
  """
  use Supervisor
  require Logger

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [{Bus.PubSub, []}]

    opts = [strategy: :one_for_one]

    _ = Logger.info("Starting #{inspect(__MODULE__)}")
    Supervisor.init(children, opts)
  end
end
