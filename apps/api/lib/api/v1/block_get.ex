defmodule API.V1.BlockGet do
  @moduledoc """
  Fetches a block.
  """

  alias Engine.Repo
  alias Engine.DB.BlockGet
  alias ExPlasma.Encoding

  @doc """
  Fetches a block by the given hash.
  """
  def by_hash(hash) do
    block = hash |> Encoding.to_binary
  end
end
