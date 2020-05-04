defmodule Bus.Event do
  @moduledoc """
  Representation of a single event to be published on OMG event bus
  """

  @enforce_keys [:topic, :event, :payload]
  @type topic_t() :: {atom(), binary()} | binary()
  @type t() :: %__MODULE__{topic: binary(), event: atom, payload: any()}

  defstruct [:topic, :event, :payload]

  @spec new(__MODULE__.topic_t(), atom(), any()) :: __MODULE__.t()
  def new({origin, topic}, event, payload) do
    %__MODULE__{topic: "#{origin}:#{topic}", event: event, payload: payload}
  end
end
