defmodule API.V1.Controller.BlockTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.Block
  alias ExPlasma.Encoding

  describe "get_by_hash/1" do
    test "it returns a matching block" do
      transaction = insert(:deposit_transaction)
      hash = Encoding.to_hex(transaction.block.hash)
      hex_tx_bytes = [Encoding.to_hex(transaction.tx_bytes)]

      assert Block.get_by_hash(hash) ==
               {:ok, %{blknum: transaction.block.blknum, hash: hash, transactions: hex_tx_bytes, object: "block"}}
    end

    test "it returns `not_found` for missing blocks" do
      assert Block.get_by_hash("0x123456") == {:error, :not_found, "No block matching the given hash"}
    end
  end
end
