defmodule Engine.Ethereum.Event.Coordinator.SyncGuide do
  @moduledoc """
  A guiding message to a coordinated service. Tells until which root chain height it is safe to advance syncing to.

  `sync_height` - until where it is safe to process the root chain
  `root_chain_height` - until where it is safe to pre-fetch and cache the events from the root chain
  """

  defstruct [:root_chain_height, :sync_height]

  @type t() :: %__MODULE__{root_chain_height: non_neg_integer(), sync_height: non_neg_integer()}
end
