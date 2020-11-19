defmodule Engine.DB.TransactionFee.TransactionFeeQuery do
  @moduledoc """
  Queries related to transactions fees
  """

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Transaction
  alias Engine.DB.TransactionFee

  @doc """
  Query all fee transactions for a block.
  """
  def get_fees_for_block(block_id) do
    from(f in TransactionFee,
      join: t in Transaction,
      on: f.transaction_id == t.id,
      where: t.block_id == ^block_id,
      select: {f.currency, sum(f.amount)},
      group_by: f.currency
    )
  end
end
