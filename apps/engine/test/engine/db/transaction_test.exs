defmodule Engine.DB.TransactionTest do
  use Engine.DB.DataCase, async: false
  doctest Engine.DB.Transaction, import: true

  alias Engine.Configuration
  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.DB.TransactionFee
  alias Engine.Repo
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Output, as: ExPlasmaOutput
  alias ExPlasma.Output.Position
  alias ExPlasma.Transaction, as: ExPlasmaTx
  alias ExPlasma.Transaction.Type.Fee, as: ExPlasmaFee

  @max_txcount 65_000
  @eth <<0::160>>

  setup do
    _ = insert(:merged_fee)

    :ok
  end

  describe "insert/1" do
    test "decodes required fields" do
      entity = TestEntity.alice()

      %{output_id: output_id} = insert(:deposit_output, %{amount: 2})

      outputs =
        Enum.map([build(:output, %{amount: 1})], fn %{output_data: output_data} ->
          ExPlasmaOutput.decode!(output_data)
        end)

      transaction =
        Builder.new(ExPlasma.payment_v1(), %{inputs: [ExPlasmaOutput.decode_id!(output_id)], outputs: outputs})

      tx_bytes =
        transaction
        |> Builder.sign!([entity.priv_encoded])
        |> ExPlasma.encode!()

      {:ok, tx_hash} = ExPlasma.Transaction.hash(transaction)

      assert {:ok, %{transaction: inserted_transaction}} = Transaction.insert(tx_bytes)

      assert inserted_transaction.tx_type == 1
      assert inserted_transaction.tx_bytes == tx_bytes
      assert inserted_transaction.tx_hash == tx_hash
    end

    test "inserts the outputs" do
      entity = TestEntity.alice()
      input_blknum = 1
      _ = insert(:deposit_output, %{blknum: input_blknum, amount: 3})

      o_1_data = [token: @eth, amount: 1, output_guard: <<1::160>>]
      o_2_data = [token: @eth, amount: 1, output_guard: <<1::160>>]

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum, txindex: 0, oindex: 0)
        |> Builder.add_output(o_1_data)
        |> Builder.add_output(o_2_data)
        |> Builder.sign!([entity.priv_encoded])
        |> ExPlasma.encode!()

      assert {:ok, %{transaction: transaction}} = Transaction.insert(tx_bytes)

      assert [%Output{output_data: o_1_data_enc}, %Output{output_data: o_2_data_enc}] = transaction.outputs
      assert ExPlasmaOutput.decode!(o_1_data_enc).output_data == Enum.into(o_1_data, %{})
      assert ExPlasmaOutput.decode!(o_2_data_enc).output_data == Enum.into(o_1_data, %{})
    end

    test "inserts the inputs" do
      entity = TestEntity.alice()
      input_blknum1 = 1
      %{id: id1} = insert(:deposit_output, %{blknum: input_blknum1, amount: 1})
      input_blknum2 = 2
      %{id: id2} = insert(:deposit_output, %{blknum: input_blknum2, amount: 1})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum1, txindex: 0, oindex: 0)
        |> Builder.add_input(blknum: input_blknum2, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: @eth, amount: 1)
        |> Builder.sign!([entity.priv_encoded, entity.priv_encoded])
        |> ExPlasma.encode!()

      assert {:ok, %{transaction: transaction}} = Transaction.insert(tx_bytes)

      assert [input1, input2] = transaction.inputs
      assert input1.id == id1
      assert input1.state == :spent
      assert input2.id == id2
      assert input2.state == :spent
    end

    test "inserts paid fees" do
      entity = TestEntity.alice()
      input_blknum1 = 1
      _ = insert(:deposit_output, %{blknum: input_blknum1, amount: 2})
      input_blknum2 = 2
      _ = insert(:deposit_output, %{blknum: input_blknum2, amount: 1, token: <<1::160>>})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: input_blknum1, txindex: 0, oindex: 0)
        |> Builder.add_input(blknum: input_blknum2, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<1::160>>, amount: 1)
        |> Builder.sign!([entity.priv_encoded, entity.priv_encoded])
        |> ExPlasma.encode!()

      assert {:ok, %{transaction: transaction}} = Transaction.insert(tx_bytes)

      assert [%TransactionFee{amount: 1, currency: <<0::160>>}] =
               Repo.all(from(f in TransactionFee, where: f.transaction_id == ^transaction.id))
    end

    test "fails when inputs are not signed correctly" do
      %{priv_encoded: priv_encoded_1, addr: addr_1} = TestEntity.alice()
      %{priv_encoded: priv_encoded_2, addr: addr_2} = TestEntity.bob()

      insert(:deposit_output, %{output_guard: addr_1, token: @eth, amount: 10, blknum: 1})
      insert(:deposit_output, %{output_guard: addr_2, token: @eth, amount: 10, blknum: 2})

      tx_bytes =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_input(blknum: 2, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: @eth, amount: 19)
        |> Builder.sign!([priv_encoded_2, priv_encoded_1])
        |> ExPlasma.encode!()

      assert {:error, changeset} = Transaction.insert(tx_bytes)
      assert("Given signatures do not match the inputs owners" in errors_on(changeset).witnesses)
      assert 0 = Repo.one(from(t in Transaction, select: count(t.id)))
    end

    test "attaches transaction to a forming block" do
      block = insert(:block)
      tx_bytes = transaction_bytes()
      {:ok, %{transaction: tx}} = Transaction.insert(tx_bytes)

      assert tx.block.id == block.id
      assert tx.tx_index == 0
    end

    test "inserting first transaction in the child-chain creates a block with nonce = 0" do
      tx_bytes = transaction_bytes()
      {:ok, _} = Transaction.insert(tx_bytes)

      nonce = Repo.one(from(b in Block, select: b.nonce))
      assert nonce == 0
    end

    test "does not insert new block when transaction can be accepted in currently forming block" do
      _ = insert(:block)

      tx_bytes1 = transaction_bytes()
      {:ok, _} = Transaction.insert(tx_bytes1)

      tx_bytes2 = transaction_bytes()
      {:ok, _} = Transaction.insert(tx_bytes2)

      number_of_blocks = Repo.one(from(b in Block, select: count(b.id)))
      assert number_of_blocks == 1
    end

    test "assigns consecutive transaction indicies" do
      _ = insert(:block)

      tx_bytes1 = transaction_bytes()
      {:ok, %{transaction: tx1}} = Transaction.insert(tx_bytes1)

      tx_bytes2 = transaction_bytes()
      {:ok, %{transaction: tx2}} = Transaction.insert(tx_bytes2)

      assert tx1.tx_index + 1 == tx2.tx_index
    end

    test "does not create conflicts when inserting multiple transaction concurrently" do
      no_conflicts =
        1..10
        |> Enum.map(fn _ -> transaction_bytes() end)
        |> Enum.map(fn tx_bytes -> Task.async(fn -> Transaction.insert(tx_bytes) end) end)
        |> Enum.map(fn task -> Task.await(task) end)
        |> Enum.all?(fn
          {:ok, _} -> true
          _ -> false
        end)

      assert no_conflicts

      [tx1 | transactions] = Repo.all(from(t in Transaction))
      refute tx1.block_id == nil

      all_in_same_block = Enum.all?(transactions, fn t -> t.block_id == tx1.block_id end)
      assert all_in_same_block
    end

    test "assigns positions to outputs" do
      tx_bytes =
        transaction_bytes(%{
          input_amount: 3,
          outputs: [build(:output, %{amount: 1}), build(:output, %{amount: 1})]
        })

      {:ok, %{transaction: transaction}} = Transaction.insert(tx_bytes)

      expected_position = [
        Position.pos(%{blknum: transaction.block.blknum, txindex: transaction.tx_index, oindex: 0}),
        Position.pos(%{blknum: transaction.block.blknum, txindex: transaction.tx_index, oindex: 1})
      ]

      actual_positions = Enum.map(transaction.outputs, fn output -> output.position end)

      assert expected_position == actual_positions
    end

    test "finalizes current forming block and inserts new one if transaction limit for a block is reached" do
      block = insert(:block)

      # we determine number of transactions in a block by querying for max transaction index in the block
      _ = insert(:payment_v1_transaction, %{block: block, tx_index: @max_txcount})

      tx_bytes = transaction_bytes()
      {:ok, %{transaction: transaction}} = Transaction.insert(tx_bytes)

      refute transaction.block.id == block.id

      finalizing_block = Repo.get(Block, block.id)
      assert finalizing_block.state == Block.state_finalizing()

      forming_block = Repo.get(Block, transaction.block.id)
      assert forming_block.state == Block.state_forming()
    end
  end

  describe "get_by/2" do
    test "returns the transaction given a query and preloads" do
      %{id: id_1, inputs: [%{id: input_id}]} = insert(:payment_v1_transaction)
      %{tx_hash: tx_hash_2} = insert(:payment_v1_transaction)

      assert %{id: ^id_1, inputs: [%{id: ^input_id}]} = Transaction.get_by([id: id_1], :inputs)

      assert %{tx_hash: ^tx_hash_2, inputs: %Ecto.Association.NotLoaded{}} =
               Transaction.get_by([tx_hash: tx_hash_2], [])
    end
  end

  describe "insert_fee_transaction/4" do
    setup do
      block = insert(:block)

      {:ok, %{block: block}}
    end

    test "sets block, transaction index, tx_type and tx_bytes for a fee transaction", %{block: block} do
      assert {:ok, transaction} = Transaction.insert_fee_transaction(Repo, {@eth, Decimal.new(1)}, block, 1)
      assert transaction.tx_index == 1
      assert transaction.block == block
      assert transaction.tx_type == ExPlasma.fee()

      expected_tx_bytes = fee_transaction_bytes(block.blknum)
      assert transaction.tx_bytes == expected_tx_bytes
    end

    test "assign positions to fee transaction outputs and sets outputs owner to fee claimer address", %{block: block} do
      tx_index = 1

      assert {:ok, %Transaction{outputs: [output]}} =
               Transaction.insert_fee_transaction(Repo, {@eth, Decimal.new(1)}, block, tx_index)

      expected_position = Position.pos(%{blknum: block.blknum, txindex: tx_index, oindex: 0})
      assert output.position == expected_position

      owner = Configuration.fee_claimer_address()

      assert %{output_data: %{amount: 1, output_guard: ^owner, token: @eth}} =
               ExPlasmaOutput.decode!(output.output_data)
    end
  end

  defp fee_transaction_bytes(blknum) do
    owner = Configuration.fee_claimer_address()

    {:ok, fee_tx} =
      ExPlasma.fee()
      |> Builder.new(
        outputs: [
          ExPlasmaFee.new_output(owner, @eth, 1)
        ]
      )
      |> ExPlasmaTx.with_nonce(%{blknum: blknum, token: @eth})

    ExPlasma.encode!(fee_tx, signed: true)
  end

  defp transaction_bytes(attrs \\ %{}) do
    entity = TestEntity.alice()

    %{output_id: output_id} = insert(:deposit_output, %{amount: Map.get(attrs, :input_amount, 2)})

    outputs =
      attrs
      |> Map.get(:outputs, [build(:output, %{amount: 1})])
      |> Enum.map(fn %{output_data: output_data} -> ExPlasmaOutput.decode!(output_data) end)

    ExPlasma.payment_v1()
    |> Builder.new(%{inputs: [ExPlasmaOutput.decode_id!(output_id)], outputs: outputs})
    |> Builder.sign!([entity.priv_encoded])
    |> ExPlasma.encode!()
  end
end
