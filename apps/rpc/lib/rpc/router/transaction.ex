defmodule RPC.Router.Transaction do
  @moduledoc """
  Produces responses for /transaction.submit
  """

  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Encoding

  def submit(%{"transaction" => hex_tx_bytes}) do
    {:ok, transaction} =
      hex_tx_bytes
      |> Encoding.to_binary()
      |> Transaction.decode()
      |> Repo.insert()

    %{tx_hash: Encoding.to_hex(transaction.tx_hash)}
  end

  def submit(_) do
    %{
      object: "error",
      code: "",
      description: "",
      messages: %{error_key: "invalid_param"}
    }
  end

end
