defmodule API.V1.Controllere.TransactionControllerTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.TransactionController
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Encoding

  setup do
    _ = insert(:fee, hash: "55", term: :no_fees_required, type: :merged_fees)

    :ok
  end

  describe "submit/1" do
    test "decodes and inserts a tx_bytes into the DB" do
      entity = TestEntity.alice()

      %{output_id: output_id} = insert(:deposit_output, amount: 10, output_guard: entity.addr)
      %{output_data: output_data} = build(:output, output_guard: entity.addr, amount: 10)

      transaction =
        Builder.new(ExPlasma.payment_v1(), %{
          inputs: [ExPlasma.Output.decode_id!(output_id)],
          outputs: [ExPlasma.Output.decode!(output_data)]
        })

      tx_bytes =
        transaction
        |> Builder.sign!([entity.priv_encoded])
        |> ExPlasma.encode!()
        |> Encoding.to_hex()

      {:ok, tx_hash} = ExPlasma.Transaction.hash(transaction)

      assert TransactionController.submit(tx_bytes) == {:ok, %{tx_hash: Encoding.to_hex(tx_hash)}}
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
