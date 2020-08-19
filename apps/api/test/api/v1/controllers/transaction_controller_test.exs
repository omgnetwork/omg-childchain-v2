defmodule API.V1.Controllere.TransactionTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.Transaction
  alias ExPlasma.Builder
  alias ExPlasma.Encoding

  describe "submit/1" do
    test "decodes and inserts a tx_bytes into the DB" do
      _ = insert(:deposit_transaction)
      txn = build(:payment_v1_transaction)
      tx_hash = Encoding.to_hex(txn.tx_hash)
      tx_bytes = Encoding.to_hex(txn.tx_bytes)

      assert Transaction.submit(tx_bytes) == {:ok, %{tx_hash: tx_hash, object: "transaction"}}
    end

    test "it raises an error if the tranasaction is invalid" do
      invalid_hex_tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_output(output_guard: <<0::160>>, token: <<0::160>>, amount: 0)
        |> Builder.sign!([])
        |> ExPlasma.encode()
        |> Encoding.to_hex()

      assert {:error, changeset} = Transaction.submit(invalid_hex_tx_bytes)
      assert "Cannot be zero" in errors_on(changeset).amount
    end
  end
end
