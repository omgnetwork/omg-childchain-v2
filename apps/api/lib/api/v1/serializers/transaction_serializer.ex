defmodule API.V1.Serializer.Transaction do
  @moduledoc """
  """

  alias ExPlasma.Encoding

  def serialize_hash(transaction) do
    %{tx_hash: Encoding.to_hex(transaction.tx_hash)}
  end
end
