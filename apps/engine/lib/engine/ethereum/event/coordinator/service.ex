defmodule Engine.Ethereum.Event.Coordinator.Service do
  @moduledoc """
  Represents a state of a service that is coordinated by `Coordinator.Core`
  """

  defstruct synced_height: nil, pid: nil

  @type t() :: %__MODULE__{synced_height: pos_integer(), pid: pid()}
end
