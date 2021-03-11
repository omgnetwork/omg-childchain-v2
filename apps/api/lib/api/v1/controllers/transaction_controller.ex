defmodule API.V1.Controller.TransactionController do
  @moduledoc """
  Transactions related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View.TransactionView
  alias Engine.DB.Transaction

  @doc """
  Validate and insert the tx_bytes.
  """
  @spec submit(String.t()) :: {:ok, TransactionView.serialized_transaction()} | {:error, atom() | Ecto.Changeset.t()}
  @decorate trace(service: :ecto, type: :backend)
  def submit(hex_tx_bytes) do
    case Transaction.insert(hex_tx_bytes) do
      {:ok, transaction} -> {:ok, TransactionView.serialize(transaction)}
      error -> error
    end
  end

  @spec batch_submit(list(String.t())) ::
          {:ok, list(TransactionView.serialized_transaction())} | list({:error, atom() | Ecto.Changeset.t()})
  def batch_submit(hex_tx_bytes) do
    case Transaction.insert_batch(hex_tx_bytes) do
      {:ok, transactions} -> {:ok, TransactionView.serialize(transactions)}
      error -> error
    end
  end
end
