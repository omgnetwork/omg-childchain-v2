defmodule API.V1.View.TransactionView do
  @moduledoc """
  Contain functions that serialize transactions into different format
  """

  alias ExPlasma.Encoding

  @type serialized_transaction() :: %{
          required(:tx_hash) => String.t(),
          required(:blknum) => pos_integer(),
          required(:tx_index) => non_neg_integer()
        }

  @spec serialize(map()) :: serialized_transaction()
  def serialize(transaction) do
    %{tx_hash: Encoding.to_hex(transaction.tx_hash), blknum: transaction.block.blknum, tx_index: transaction.tx_index}
  end
end
