defmodule API.V1.BlockGetTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.BlockGet
  alias ExPlasma.Encoding

  describe "by_hash/1" do
    test "it returns a matching block" do
      transaction = insert(:deposit_transaction)
      hash = Encoding.to_hex(transaction.block.hash)
      hex_tx_bytes = [Encoding.to_hex(transaction.tx_bytes)]

      assert BlockGet.by_hash(hash) == %{blknum: transaction.block.number, hash: hash, transactions: hex_tx_bytes}
    end

    test "it returns an empty hash for missing blocks" do
      assert BlockGet.by_hash("0x123456") == %{}
    end
  end
end
