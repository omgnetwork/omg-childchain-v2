defmodule API.V1.Controller.Block do
  @moduledoc """
  Contains block related API functions.
  """

  use Spandex.Decorators

  alias API.V1.Serializer
  alias Engine.DB.Block
  alias Engine.Repo
  alias ExPlasma.Encoding

  @type get_by_hash_error() :: {:error, :decoding_error} | {:error, :not_found, String.t()}

  @doc """
  Fetches a block by the given hash from the params.
  """
  @spec get_by_hash(String.t()) :: {:ok, Serializer.Block.serialized_block()} | get_by_hash_error()
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

      {:error, :decoding_error} = error ->
        error
    end
  end
end
