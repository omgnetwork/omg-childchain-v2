defmodule API.V1.View.BlockViewTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.View.BlockView
  alias ExPlasma.Encoding

  describe "serialize/1" do
    test "serialize a block" do
      block = :block |> build() |> Engine.Repo.preload(:transactions)

      assert BlockView.serialize(block) == %{
               blknum: block.blknum,
               hash: Encoding.to_hex(block.hash),
               transactions: Enum.map(block.transactions, &Encoding.to_hex(&1.tx_bytes))
             }
    end
  end
end
