defmodule API.V1.Controller.BlockControllerTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.BlockController
  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias ExPlasma.Encoding

  describe "get_by_hash/1" do
    test "it returns a matching block" do
      %{id: id} = insert(:payment_v1_transaction)
      Block.form()
      transaction = Transaction |> Repo.get(id) |> Repo.preload(:block)

      hash = Encoding.to_hex(transaction.block.hash)
      hex_tx_bytes = [Encoding.to_hex(transaction.tx_bytes)]

      assert BlockController.get_by_hash(hash) ==
               {:ok, %{blknum: transaction.block.blknum, hash: hash, transactions: hex_tx_bytes}}
    end

    test "it returns `no_block_matching_hash` for missing blocks" do
      assert BlockController.get_by_hash("0x123456") == {:error, :no_block_matching_hash}
    end
  end
end
