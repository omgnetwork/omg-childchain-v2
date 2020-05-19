defmodule RPC.Router.Block do
  @moduledoc """
  Module to produce /block.get responses
  """

  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.Repo
  alias ExPlasma.Encoding

  @doc """
  Fetch the given block by hash, then return it with a json-encodable payload.
  """
  @spec get_by_hash(map()) :: map()
  def get_by_hash(%{"hash" => hash}) do
    block = hash |> Encoding.to_binary() |> Block.get_by_hash()

    case block do
      nil ->
        %{}
      block ->
        block = Repo.preload(block, :transactions)
        %{
          blknum: block.number,
          hash: Encoding.to_hex(block.hash),
          transactions: Enum.map(block.transactions, fn txn -> Encoding.to_hex(txn.tx_bytes) end)
        }
    end
  end

  def get_by_hash(_) do
    %{
      object: "error",
      code: "",
      description: "",
      messages: %{error_key: "not_found"}
    }
  end
end
