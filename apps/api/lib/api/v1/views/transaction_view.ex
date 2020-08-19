defmodule API.V1.View.Transaction do
  @moduledoc """
  Contain functions that serialize transactions into different format
  """

  alias ExPlasma.Encoding

  @type serialized_hash() :: %{
          required(:tx_hash) => String.t()
        }

  def serialize_hash(transaction) do
    %{object: "transaction", tx_hash: Encoding.to_hex(transaction.tx_hash)}
  end
end
