defmodule API.V1.Serializer.BlockTest do
  @moduledoc """
  """

  use Engine.DB.DataCase, async: true

  alias API.V1.Serializer.Block
  alias ExPlasma.Encoding

  describe "serialize/1" do
    test "serialize a block" do
      block = :block |> build() |> Engine.Repo.preload(:transactions)

      assert Block.serialize(block) == %{
               blknum: block.number,
               hash: Encoding.to_hex(block.hash),
               transactions: Enum.map(block.transactions, &Encoding.to_hex(&1.tx_bytes))
             }
    end
  end
end
