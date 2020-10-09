defmodule API.V1.View.TransactionViewTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.View.TransactionView
  alias ExPlasma.Encoding

  describe "serialize/1" do
    test "serialize a transaction" do
      block = build(:block)
      transaction = build(:payment_v1_transaction, %{block: block})

      assert TransactionView.serialize(transaction) == %{
               tx_hash: Encoding.to_hex(transaction.tx_hash),
               blknum: block.blknum,
               tx_index: 0
             }
    end
  end
end
