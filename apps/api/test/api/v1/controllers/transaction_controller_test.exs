defmodule API.V1.Controllere.TransactionControllerTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.TransactionController
  alias ExPlasma.Builder
  alias ExPlasma.Encoding

  setup do
    _ = insert(:fee, hash: "55", term: :no_fees_required, type: :merged_fees)

    :ok
  end

  describe "submit/1" do
    test "decodes and inserts a tx_bytes into the DB" do
      txn = build(:payment_v1_transaction)
      tx_hash = Encoding.to_hex(txn.tx_hash)
      tx_bytes = Encoding.to_hex(txn.tx_bytes)

      assert TransactionController.submit(tx_bytes) == {:ok, %{tx_hash: tx_hash}}
    end

    test "it raises an error if the tranasaction is invalid" do
      invalid_hex_tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_output(output_guard: <<0::160>>, token: <<0::160>>, amount: 0)
        |> Builder.sign!([])
        |> ExPlasma.encode!()
        |> Encoding.to_hex()

      assert {:error, changeset} = TransactionController.submit(invalid_hex_tx_bytes)
      assert "Cannot be zero" in errors_on(changeset).amount
    end
  end
end
