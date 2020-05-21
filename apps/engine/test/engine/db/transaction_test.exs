defmodule Engine.DB.TransactionTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Transaction, import: true

  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction

  describe "decode/1" do
    test "decodes tx_bytes and validates" do
      params = build(:deposit_transaction, amount: 0)
      changeset = Transaction.decode(params.tx_bytes)

      refute changeset.valid?
      assert {"can not be zero", []} = changeset.errors[:amount]
    end

    test "builds the outputs" do
      transaction = build(:deposit_transaction)
      assert %Output{} = hd(transaction.outputs)
    end

    test "builds the inputs" do
      transaction = build(:payment_v1_transaction)
      assert %Output{} = hd(transaction.inputs)
    end

    # TODO: move to specific type test
    test "validates amounts" do
      output_guard_1 = <<1::160>>
      output_guard_2 = <<2::160>>

      token_1 = <<0::160>>
      token_2 = <<1::160>>
      token_3 = <<2::160>>

      _ =
        :output
        |> insert(
          output_id:
            %{blknum: 1, txindex: 0, oindex: 0}
            |> ExPlasma.Output.Position.pos()
            |> ExPlasma.Output.Position.to_map(),
          output_data: %{output_guard: output_guard_1, token: token_1, amount: 1},
          output_type: 1,
          state: "confirmed"
        )

      _ =
        :output
        |> insert(
          output_id:
            %{blknum: 2, txindex: 0, oindex: 0}
            |> ExPlasma.Output.Position.pos()
            |> ExPlasma.Output.Position.to_map(),
          output_data: %{output_guard: output_guard_1, token: token_1, amount: 1},
          output_type: 1,
          state: "confirmed"
        )

      _ =
        :output
        |> insert(
          output_id:
            %{blknum: 3, txindex: 0, oindex: 0}
            |> ExPlasma.Output.Position.pos()
            |> ExPlasma.Output.Position.to_map(),
          output_data: %{output_guard: output_guard_1, token: token_2, amount: 2},
          output_type: 1,
          state: "confirmed"
        )

      a =
        :output
        |> insert(
          output_id:
            %{blknum: 4, txindex: 0, oindex: 0}
            |> ExPlasma.Output.Position.pos()
            |> ExPlasma.Output.Position.to_map(),
          output_data: %{output_guard: output_guard_1, token: token_3, amount: 3},
          output_type: 1,
          state: "confirmed"
        )

      changeset =
        [tx_type: 1]
        |> ExPlasma.Builder.new()
        |> ExPlasma.Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> ExPlasma.Builder.add_input(blknum: 2, txindex: 0, oindex: 0)
        |> ExPlasma.Builder.add_input(blknum: 3, txindex: 0, oindex: 0)
        |> ExPlasma.Builder.add_input(blknum: 4, txindex: 0, oindex: 0)
        |> ExPlasma.Builder.add_output(output_guard: output_guard_2, token: token_1, amount: 2)
        |> ExPlasma.Builder.add_output(output_guard: output_guard_2, token: token_2, amount: 2)
        |> ExPlasma.Builder.add_output(output_guard: output_guard_2, token: token_3, amount: 3)
        |> ExPlasma.encode()
        |> Transaction.decode()

      assert changeset.valid?
    end

    test "references existing inputs" do
      %Transaction{outputs: [output]} = insert(:deposit_transaction)
      %Transaction{tx_bytes: tx_bytes} = build(:payment_v1_transaction)

      changeset = Transaction.decode(tx_bytes)
      input = changeset |> get_field(:inputs) |> hd()

      assert changeset.valid?
      assert output.id == input.id
    end

    test "builds the tx_hash" do
      _ = insert(:deposit_transaction)
      transaction = build(:payment_v1_transaction)
      changeset = Transaction.decode(transaction.tx_bytes)
      tx_hash = ExPlasma.hash(transaction.tx_bytes)

      assert changeset.valid?
      assert tx_hash == get_field(changeset, :tx_hash)
    end
  end
end
