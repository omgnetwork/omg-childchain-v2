defmodule API.V1.View.BlockView do
  @moduledoc """
  Contain functions that serialize blocks into different format
  """

  alias ExPlasma.Encoding

  @type serialized_block() :: %{
          required(:blknum) => pos_integer(),
          required(:hash) => String.t(),
          required(:transactions) => [String.t()]
        }

  @spec serialize(map()) :: serialized_block()
  def serialize(block) do
    %{
      blknum: block.blknum,
      hash: Encoding.to_hex(block.hash),
      transactions: Enum.map(block.transactions, &Encoding.to_hex(&1.tx_bytes))
    }
  end
end
