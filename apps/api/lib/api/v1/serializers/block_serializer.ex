defmodule API.V1.Serializer.Block do
  @moduledoc """
  """

  alias ExPlasma.Encoding

  def serialize(block) do
    %{
      blknum: block.number,
      hash: Encoding.to_hex(block.hash),
      transactions: Enum.map(block.transactions, &Encoding.to_hex(&1.tx_bytes))
    }
  end
end
