defmodule Engine.DB.Transaction.TransactionChangesetTest do
  use Engine.DB.DataCase, async: true

  alias Ecto.Changeset
  alias Engine.Configuration
  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.TransactionChangeset
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Output.Position
  alias ExPlasma.Transaction, as: ExPlasmaTx
  alias ExPlasma.Transaction.Type.Fee, as: ExPlasmaFee

  @eth <<0::160>>

  setup do
    _ = insert(:merged_fee)
    :ok
  end

  describe "new_transaction_changeset/2" do
    test "assigns values to fields" do
      {{tx_bytes, decoded_t, fees}, tx_hash} = valid_payment_transaction_changeset_params()
      assert changeset = TransactionChangeset.new_transaction_changeset(%Transaction{}, tx_bytes, decoded_t, fees)
      assert changeset.valid?

      transaction = Changeset.apply_changes(changeset)
      assert decoded_t.tx_type == transaction.tx_type
      assert tx_hash == transaction.tx_hash
      assert tx_bytes == transaction.tx_bytes
      assert decoded_t.witnesses == transaction.witnesses

      assert [%{output_data: output_data}] = transaction.outputs
      assert [%{output_id: input_id}] = transaction.inputs

      expected_output_data =
        decoded_t.outputs
        |> hd()
        |> encoded_output_data()

      expected_input_data =
        decoded_t.inputs
        |> hd()
        |> encoded_output_id()

      assert expected_input_data == input_id
      assert expected_output_data == output_data
    end
  end

  describe "set_blknum_and_tx_index/2" do
    test "sets block number, transaction index and output positions" do
      tx_index = 1
      block = build(:block)
      {{tx_bytes, decoded_t, fees}, _tx_hash} = valid_payment_transaction_changeset_params()
      changeset = TransactionChangeset.new_transaction_changeset(%Transaction{}, tx_bytes, decoded_t, fees)

      update = TransactionChangeset.set_blknum_and_tx_index(changeset, %{block: block, next_tx_index: tx_index})

      assert tx_index == Changeset.fetch_change!(update, :tx_index)

      %{data: block_change} = Changeset.fetch_change!(update, :block)

      assert block_change.blknum == block.blknum

      output_change =
        update
        |> Changeset.fetch_change!(:outputs)
        |> hd()
        |> Changeset.fetch_change!(:position)

      expected_output_position = Position.pos(%{blknum: block.blknum, txindex: tx_index, oindex: 0})
      assert expected_output_position == output_change
    end
  end

  describe "new_fee_transaction_changeset/2" do
    test "assigns values to fields" do
      block = build(:block)
      plasma_output = ExPlasmaFee.new_output(Configuration.fee_claimer_address(), @eth, 1)

      {:ok, fee_tx} =
        ExPlasma.fee()
        |> Builder.new(outputs: [plasma_output])
        |> ExPlasmaTx.with_nonce(%{blknum: block.blknum, token: @eth})

      tx_bytes = ExPlasma.encode!(fee_tx, signed: true)
      {:ok, tx_hash} = ExPlasma.Transaction.hash(tx_bytes)

      params = %{
        outputs: Enum.map(fee_tx.outputs, &Map.from_struct/1),
        tx_type: ExPlasma.fee(),
        tx_hash: tx_hash,
        tx_bytes: tx_bytes
      }

      changeset = TransactionChangeset.new_fee_transaction_changeset({@eth, Decimal.new(1)}, block)
      assert changeset.valid?

      fee_transaction = Changeset.apply_changes(changeset)

      assert params[:tx_type] == fee_transaction.tx_type
      assert params[:tx_hash] == fee_transaction.tx_hash
      assert params[:tx_bytes] == fee_transaction.tx_bytes

      assert [%{output_data: output_data}] = fee_transaction.outputs

      expected_output_data =
        fee_tx.outputs
        |> hd()
        |> encoded_output_data()

      assert expected_output_data == output_data
    end
  end

  def valid_payment_transaction_changeset_params() do
    entity = TestEntity.alice()

    %{output_id: output_id} = insert(:deposit_output, %{amount: 2})

    %{output_data: output_data} = build(:output, %{amount: 1})
    output = ExPlasma.Output.decode!(output_data)

    {:ok, transaction} =
      ExPlasma.payment_v1()
      |> Builder.new(%{inputs: [ExPlasma.Output.decode_id!(output_id)], outputs: [output]})
      |> Builder.sign!([entity.priv_encoded])
      |> ExPlasma.Transaction.with_witnesses()

    tx_bytes = ExPlasma.encode!(transaction)
    {:ok, tx_hash} = ExPlasma.Transaction.hash(transaction)

    {{tx_bytes, transaction, %{@eth => [1]}}, tx_hash}
  end

  defp encoded_output_data(params) do
    {:ok, encoded_output_data} = ExPlasma.Output.encode(params)

    encoded_output_data
  end

  defp encoded_output_id(params) do
    {:ok, encoded_output_id} = ExPlasma.Output.encode(params, as: :input)

    encoded_output_id
  end
end
