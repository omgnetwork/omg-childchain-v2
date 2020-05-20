defmodule API.V1.BlockGet do
  @moduledoc """
  Fetches a block and returns data for the API response.
  """

  alias Engine.DB.Block
  alias Engine.Repo
  alias ExPlasma.Encoding

  @doc """
  Fetches a block by the given hash from the params.
  """
  def by_hash(%{"hash" => hash}) do
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

  # elixir-omg really just returns 1 type of error for this...
  def by_hash(_) do
    %{
      object: :error,
      code: "operation:bad_request",
      messages: %{
        validation_error: %{parameter: :hash}
      }
    }
  end
end
