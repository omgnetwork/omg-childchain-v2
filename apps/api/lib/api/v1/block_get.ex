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
  def by_hash("0x" <> _rest = hash) do
    block = hash |> Encoding.to_binary() |> Block.get_by_hash()

    case block do
      [] ->
        %{}

      [block | _] ->
        block = Repo.preload(block, :transactions)

        %{
          blknum: block.number,
          hash: Encoding.to_hex(block.hash),
          transactions: Enum.map(block.transactions, fn txn -> Encoding.to_hex(txn.tx_bytes) end)
        }
    end
  end

  def by_hash(_), do: raise ArgumentError, "hash"
end
