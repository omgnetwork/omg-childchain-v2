defmodule API.V1.View.TransactionTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.View.Transaction
  alias ExPlasma.Encoding

  describe "serialize/1" do
    test "serialize a transaction" do
      _ = insert(:fee, hash: "55", term: :no_fees_required, type: :merged_fees)

      transaction = build(:payment_v1_transaction)

      assert Transaction.serialize_hash(transaction) == %{
               tx_hash: Encoding.to_hex(transaction.tx_hash),
               object: "transaction"
             }
    end
  end
end
