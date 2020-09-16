defmodule API.V1.Controller.BlockControllerTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.BlockController
  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias ExPlasma.Encoding

  describe "get_by_hash/1" do
    test "it returns a matching block" do
      _ = insert(:fee, hash: "22", type: :merged_fees)
      %{id: id} = insert(:payment_v1_transaction)
      Block.form()
      transaction = Transaction |> Repo.get(id) |> Repo.preload(:block)

      hash = Encoding.to_hex(transaction.block.hash)
      hex_tx_bytes = [Encoding.to_hex(transaction.tx_bytes)]

      assert BlockController.get_by_hash(hash) ==
               {:ok, %{blknum: transaction.block.blknum, hash: hash, transactions: hex_tx_bytes}}
    end

    test "it returns `not_found` for missing blocks" do
      assert BlockController.get_by_hash("0x123456") == {:error, :not_found, "No block matching the given hash"}
    end
  end
end
