defmodule API.V1.TransactionSubmitTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.TransactionSubmit
  alias ExPlasma.Encoding

  @moduletag :focus

  describe "submit/1" do
    test "decodes and inserts a tx_bytes into the DB" do
      _ = insert(:deposit_transaction)
      txn = build(:payment_v1_transaction)
      tx_hash = Encoding.to_hex(txn.tx_hash)
      tx_bytes = Encoding.to_hex(txn.tx_bytes)

      assert %{tx_hash: ^tx_hash} = TransactionSubmit.submit(tx_bytes)
    end

    test "it raises an error if the hash is invalid with no 0x prefix" do
      assert_raise ArgumentError, "transaction", fn ->
        TransactionSubmit.submit("0000")
      end
    end
  end
end
