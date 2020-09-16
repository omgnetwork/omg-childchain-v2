defmodule API.V1.View.TransactionView do
  @moduledoc """
  Contain functions that serialize transactions into different format
  """

  alias ExPlasma.Encoding

  @type serialized_hash() :: %{required(:tx_hash) => String.t()}

  @spec serialize_hash(map()) :: serialized_hash()
  def serialize_hash(transaction) do
    %{tx_hash: Encoding.to_hex(transaction.tx_hash)}
  end
end
