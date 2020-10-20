defmodule Engine.DB.Transaction.TransactionQuery do
  @moduledoc """
  Queries related to transactions
  """

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Transaction

  @doc """
  Query all transactions that have not been formed into a block.
  """
  def select_pending(), do: from(t in Transaction, where: is_nil(t.block_id))

  @doc """
  Find transactions by the tx_hash.
  """
  def select_by_tx_hash(tx_hash), do: from(t in Transaction, where: t.tx_hash == ^tx_hash)

  @doc """
  Querries for biggest tx index for a given block id
  """
  def select_max_tx_index_for_block(block_id) do
    from(t in Transaction, where: t.block_id == ^block_id, select: max(t.tx_index))
  end

  @doc """
  Querries for all transaction in a block
  """
  def fetch_transactions_from_block(block_id) do
    from(transaction in Transaction, where: transaction.block_id == ^block_id, order_by: transaction.tx_index)
  end
end