defmodule API.V1.Controller.Block do
  @moduledoc """
  Contains block related API functions.
  """

  use Spandex.Decorators

  alias API.V1.Serializer
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
  # @spec by_hash(String.t()) :: block_response()
  @decorate trace(service: :ecto, type: :backend)
  def get_by_hash(hash) do
    with {:ok, decoded_hash} <- Encoding.to_binary(hash),
         block when is_map(block) <- decoded_hash |> Block.query_by_hash() |> Repo.one() do
      serialized =
        block
        |> Repo.preload(:transactions)
        |> Serializer.Block.serialize()

      {:ok, serialized}
    else
      nil ->
        {:error, :not_found, "No block matching the given hash"}

      error ->
        error
    end
  end
end
