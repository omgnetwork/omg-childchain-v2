defmodule API.V1.Controller.Transaction do
  @moduledoc """
  Contains transaction related API functions.
  """

  use Spandex.Decorators

  alias API.V1.Serializer
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Encoding

  @doc """
  Validate and insert the tx_bytes.
  """
  @spec submit(String.t()) :: {:ok, Serializer.Transaction.serialized_hash()} | {:error, atom() | Ecto.Changeset.t()}
  @decorate trace(service: :ecto, type: :backend)
  def submit("0x" <> _rest = hex_tx_bytes) do
    with {:ok, binary} <- Encoding.to_binary(hex_tx_bytes),
         {:ok, changeset} <- Transaction.decode(binary, kind: Transaction.kind_transfer()),
         {:ok, transaction} <- Repo.insert(changeset) do
      {:ok, Serializer.Transaction.serialize_hash(transaction)}
    end
  end
end
