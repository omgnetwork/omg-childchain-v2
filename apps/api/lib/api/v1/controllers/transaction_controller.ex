defmodule API.V1.Controller.TransactionController do
  @moduledoc """
  Contains transaction related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View
  alias Engine.DB.Transaction
  alias ExPlasma.Encoding

  @doc """
  Validate and insert the tx_bytes.
  """
  @spec submit(String.t()) :: {:ok, View.Transaction.serialized_hash()} | {:error, atom() | Ecto.Changeset.t()}
  @decorate trace(service: :ecto, type: :backend)
  def submit(hex_tx_bytes) do
    with {:ok, binary} <- Encoding.to_binary(hex_tx_bytes),
         {:ok, changeset} <- Transaction.decode(binary),
         {:ok, transaction} <- Transaction.insert(changeset) do
      {:ok, View.Transaction.serialize_hash(transaction)}
    end
  end
end
