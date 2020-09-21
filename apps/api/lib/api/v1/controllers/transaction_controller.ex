defmodule API.V1.Controller.TransactionController do
  @moduledoc """
  Transactions related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View.TransactionView
  alias Engine.DB.Transaction
  alias ExPlasma.Encoding

  @doc """
  Validate and insert the tx_bytes.
  """
  @spec submit(String.t()) :: {:ok, TransactionView.serialized_transaction()} | {:error, atom() | Ecto.Changeset.t()}
  @decorate trace(service: :ecto, type: :backend)
  def submit(hex_tx_bytes) do
    with {:ok, tx_bytes} <- Encoding.to_binary(hex_tx_bytes),
         {:ok, %{transaction: transaction}} <- Transaction.insert(tx_bytes) do
      {:ok, TransactionView.serialize(transaction)}
    end
  end
end
