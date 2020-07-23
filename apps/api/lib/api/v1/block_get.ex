defmodule API.V1.BlockGet do
  @moduledoc """
  Fetches a block and returns data for the API response.
  """

  use Spandex.Decorators

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
  @decorate trace(service: :ecto, type: :backend)
  def by_hash(hash) do
    with {:ok, decoded_hash} <- Encoding.to_binary(hash),
         block when not is_nil(block) <- decoded_hash |> Block.query_by_hash() |> Repo.one() do
      block = Repo.preload(block, :transactions)

      %{
        blknum: block.number,
        hash: Encoding.to_hex(block.hash),
        transactions: Enum.map(block.transactions, fn txn -> Encoding.to_hex(txn.tx_bytes) end)
      }
    else
      nil -> %{}
      error -> error
    end
  end
end
