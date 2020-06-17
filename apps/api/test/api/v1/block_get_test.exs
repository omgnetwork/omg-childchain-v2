defmodule API.V1.BlockGetTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.BlockGet
  alias ExPlasma.Encoding

  describe "by_hash/1" do
    test "it returns a matching block" do
      transaction = insert(:deposit_transaction)
      hash = Encoding.to_hex(transaction.block.hash)
      hex_tx_bytes = [Encoding.to_hex(transaction.tx_bytes)]

      assert %{blknum: _, hash: ^hash, transactions: ^hex_tx_bytes} = BlockGet.by_hash(hash)
    end

    test "it raises an error if the hash is invalid with no 0x prefix" do
      assert_raise ArgumentError, "hash value must be prefixed with \"0x\"", fn ->
        BlockGet.by_hash("0000")
      end
    end
  end
end
