defmodule API.V1.TransactionSubmit do
  @moduledoc """
  Accepts a tx_bytes param and validates and inserts the transaction into the network.
  """

  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Encoding

  @type submit_response() :: %{
    required(:tx_hash) => String.t()
  }

  @doc """
  Validate and insert the tx_bytes.
  """
  @spec submit(String.t()) :: submit_response()
  def submit("0x" <> _rest = hex_tx_bytes) do
    result =
      hex_tx_bytes
      |> Encoding.to_binary()
      |> Transaction.decode()
      |> Repo.insert()

    case result do
      {:ok, transaction} ->
        %{tx_hash: Encoding.to_hex(transaction.tx_hash)}
      {:error, changeset} ->
        raise ArgumentError, inspect(changeset.errors)
    end
  end

  def submit(_), do: raise ArgumentError, "transaction value must be prefixed with \"0x\""
end