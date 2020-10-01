defmodule API.V1.View.TransactionViewTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.View.TransactionView
  alias ExPlasma.Encoding

  describe "serialize/1" do
    test "serialize a transaction" do
      transaction = build(:payment_v1_transaction)

      assert TransactionView.serialize_hash(transaction) == %{
               tx_hash: Encoding.to_hex(transaction.tx_hash)
             }
    end
  end
end
