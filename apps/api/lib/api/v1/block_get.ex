defmodule API.V1.BlockGet do
  @moduledoc """
  Fetches a block and returns data for the API response.
  """

  alias Engine.DB.Block
  alias Engine.Repo
  alias ExPlasma.Encoding

  @type block_response() :: %{
          required(:blknum) => pos_integer(),
          required(:hash) => String.t(),
          required(:transactions) => [String.t()]
        }

  @doc """
  Fetches a block by the given hash from the params.
  """
  @spec by_hash(String.t()) :: block_response()
  def by_hash(hash) do
    block = hash |> Encoding.to_binary() |> Block.query_by_hash() |> Repo.one()

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
end
