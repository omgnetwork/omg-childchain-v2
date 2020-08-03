defmodule API.V1.Controller.Transaction do
  @moduledoc """
  Contains transaction related API functions.
  """

  use Spandex.Decorators

  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Encoding
  alias API.V1.Serializer

  @type submit_response() :: %{
          required(:tx_hash) => String.t()
        }

  @doc """
  Validate and insert the tx_bytes.
  """
  @spec submit(String.t()) :: submit_response() | no_return()
  @decorate trace(service: :ecto, type: :backend)
  def submit("0x" <> _rest = hex_tx_bytes) do
    with {:ok, binary} <- Encoding.to_binary(hex_tx_bytes),
         {:ok, changeset} <- Transaction.decode(binary, kind: Transaction.kind_transfer()),
         {:ok, transaction} <- Repo.insert(changeset) do
      {:ok, Serializer.Transaction.serialize_hash(transaction)}
    end
  end
end
