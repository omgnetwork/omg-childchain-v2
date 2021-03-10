defmodule Engine.DB.Transaction.TransactionChangeset do
  @moduledoc """
  Changesets related to transactions
  """

  use Ecto.Schema

  import Ecto.Changeset,
    only: [
      cast: 3,
      cast_assoc: 3,
      validate_required: 2,
      put_change: 3,
      put_assoc: 3,
      validate_number: 3,
      validate_length: 3
    ]

  alias Engine.DB.Output
  alias Engine.DB.Output.OutputChangeset
  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.Validator

  alias ExPlasma.Builder
  alias ExPlasma.Output.Position
  alias ExPlasma.Transaction, as: ExPlasmaTx
  alias ExPlasma.Transaction.Type.Fee, as: ExPlasmaFee

  @required_fields [:witnesses, :tx_hash, :signed_tx, :tx_bytes, :tx_type]
  @required_fee_transaction_fields [:tx_hash, :tx_bytes, :tx_type]

  def new_transaction_changeset(struct, tx_bytes, decoded, fees) do
    params = decoded |> recovered_to_map() |> Map.put(:tx_bytes, tx_bytes) |> Map.put(:fees, fees)

    struct
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> Validator.validate_protocol()
    |> Validator.associate_inputs(params)
    |> cast_assoc(:outputs, with: &Output.new/2)
    |> Validator.validate_statefully(params)
  end

  def new_fee_transaction_changeset(currency_with_amount, block) do
    {fee_transaction_bytes, output} = fee_transaction_bytes_and_output(currency_with_amount, block.blknum)
    {:ok, tx_hash} = ExPlasma.hash(fee_transaction_bytes)

    params = %{
      tx_type: ExPlasma.fee(),
      tx_bytes: fee_transaction_bytes,
      tx_hash: tx_hash,
      outputs: [Map.from_struct(output)]
    }

    %Transaction{}
    |> cast(params, @required_fee_transaction_fields)
    |> validate_required(@required_fee_transaction_fields)
    |> validate_number(:tx_type, equal_to: ExPlasma.fee())
    |> cast_assoc(:outputs, with: &Output.new/2, required: true)
    |> validate_length(:outputs, is: 1)
  end

  def set_blknum_and_tx_index(changeset, block_with_next_tx_index) do
    %{block: block, next_tx_index: tx_index} = block_with_next_tx_index

    outputs =
      changeset.changes.outputs
      |> Enum.with_index()
      |> Enum.map(fn {output_changeset, output_index} ->
        position = %{output_id: Position.new(block.blknum, tx_index, output_index)}

        output_changeset
        |> OutputChangeset.assign_position(position)
        # the simple reason why we assign a block number to a newly created output is because
        # when a plasma block is submitted, this output needs to be marked as :confirmed
        # (at this point it's state: :pending)
        # and referencing it via blknum makes the SQL update much easier and faster!
        |> OutputChangeset.assign_blknum(%{blknum: block.blknum})
      end)

    changeset
    |> put_change(:tx_index, tx_index)
    |> put_assoc(:block, block)
    |> put_assoc(:outputs, outputs)
  end

  defp fee_transaction_bytes_and_output(currency_with_amount, blknum) do
    {token, amount} = currency_with_amount
    output = ExPlasmaFee.new_output(Engine.Configuration.fee_claimer_address(), token, Decimal.to_integer(amount))

    {:ok, fee_tx} =
      ExPlasma.fee()
      |> Builder.new(outputs: [output])
      |> ExPlasmaTx.with_nonce(%{blknum: blknum, token: token})

    fee_transaction_bytes = ExPlasma.encode!(fee_tx, signed: true)
    {fee_transaction_bytes, output}
  end

  defp recovered_to_map(transaction) do
    inputs = Enum.map(transaction.inputs, &Map.from_struct/1)
    outputs = Enum.map(transaction.outputs, &Map.from_struct/1)
    {:ok, tx_hash} = ExPlasma.hash(transaction)

    %{
      signed_tx: transaction,
      inputs: inputs,
      outputs: outputs,
      tx_hash: tx_hash,
      tx_type: transaction.tx_type,
      witnesses: transaction.witnesses
    }
  end
end
