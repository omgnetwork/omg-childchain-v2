defmodule API.V1.Controller.Block do
  @moduledoc """
  Contains block related API functions.
  """

  use Spandex.Decorators

  alias API.V1.View
  alias Engine.DB.PlasmaBlock
  alias ExPlasma.Encoding

  @type get_by_hash_error() :: {:error, :decoding_error} | {:error, :not_found, String.t()}

  @doc """
  Fetches a block by the given hash from the params.
  """
  @spec get_by_hash(String.t()) :: {:ok, View.Block.serialized_block()} | get_by_hash_error()
  @decorate trace(service: :ecto, type: :backend)
  def get_by_hash(hash) do
    with {:ok, decoded_hash} <- Encoding.to_binary(hash),
         {:ok, block} <- PlasmaBlock.get_by_hash(decoded_hash, :transactions) do
      {:ok, View.Block.serialize(block)}
    else
      {:error, nil} ->
        {:error, :not_found, "No block matching the given hash"}

      {:error, :decoding_error} = error ->
        error
    end
  end
end
