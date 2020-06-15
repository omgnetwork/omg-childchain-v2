defmodule API.V1.TransactionSubmitTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.TransactionSubmit
  alias ExPlasma.Builder
  alias ExPlasma.Encoding

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

    test "it raises an error if the tranasaction is invalid" do
      assert_raise ArgumentError, "invalid tx_bytes", fn ->
        invalid_hex_tx_bytes =
          [tx_type: 1]
          |> Builder.new()
          |> Builder.add_output(output_guard: <<0::160>>, token: <<0::160>>, amount: 0)
          |> ExPlasma.encode()
          |> Encoding.to_hex()

        TransactionSubmit.submit(invalid_hex_tx_bytes)
      end
    end
  end
end
