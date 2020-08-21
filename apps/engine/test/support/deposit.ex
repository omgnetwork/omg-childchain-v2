defmodule Deposit do
  @moduledoc false
  alias ExPlasma.Encoding

  @zero_metadata <<0::256>>
  @output_type ExPlasma.payment_v1()

  defstruct [:inputs, :outputs, metadata: @zero_metadata]

  @type t() :: %__MODULE__{
          inputs: list(),
          outputs: list(),
          metadata: binary()
        }

  def new(owner, currency, amount) do
    outputs = [
      [@output_type, [Encoding.to_binary!(owner), currency, amount]]
    ]

    %__MODULE__{inputs: [], outputs: outputs, metadata: @zero_metadata}
  end
end
