defmodule API.V1.Controller.BlockController do
  @moduledoc """
  Contains block related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View.BlockView
  alias Engine.DB.Block
  alias ExPlasma.Encoding

  @type get_by_hash_error() :: {:error, :decoding_error} | {:error, :no_block_matching_hash}

  @doc """
  Fetches a block by the given hash from the params.
  """
  @spec get_by_hash(String.t()) :: {:ok, BlockView.serialized_block()} | get_by_hash_error()
  @decorate trace(service: :ecto, type: :backend)
  def get_by_hash(hash) do
    with {:ok, decoded_hash} <- Encoding.to_binary(hash),
         {:ok, block} <- Block.get_by_hash(decoded_hash, :transactions) do
      {:ok, BlockView.serialize(block)}
    end
  end
end
