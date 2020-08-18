defmodule API.V1.TransactionSubmit do
  @moduledoc """
  Accepts a tx_bytes param and validates and inserts the transaction into the network.
  """

  use Spandex.Decorators

  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Encoding

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
         {:ok, changeset} <- Transaction.decode(binary, Transaction.kind_transfer()),
         {:ok, transaction} <- Repo.insert(changeset) do
      %{tx_hash: Encoding.to_hex(transaction.tx_hash)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {key, {message, _}} = hd(changeset.errors)
        raise ArgumentError, "#{key} #{message}"

      {:error, error} ->
        raise ArgumentError, "#{error}"
    end
  end
end
