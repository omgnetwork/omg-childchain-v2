defmodule Engine.DB.Transaction.TransactionChangeset do
  @moduledoc """
  Changesets related to transactions
  """

  use Ecto.Schema
  import Ecto.Changeset, only: [cast: 3, cast_assoc: 3, validate_required: 2, put_change: 3, put_assoc: 3]

  alias Engine.DB.Output
  alias Engine.DB.Output.OutputChangeset
  alias Engine.DB.PaidFee
  alias Engine.DB.Transaction.Validator

  alias ExPlasma.Output.Position

  @required_fields [:witnesses, :tx_hash, :signed_tx, :tx_bytes, :tx_type]

  def new_transaction_changeset(struct, params) do
    {changeset, paid_fees_by_currency} =
      struct
      |> cast(params, @required_fields)
      |> validate_required(@required_fields)
      |> Validator.validate_protocol()
      |> Validator.associate_inputs(params)
      |> cast_assoc(:outputs, with: &Output.new/2)
      |> Validator.validate_statefully(params)

    associate_paid_fees(changeset, paid_fees_by_currency)
  end

  def set_blknum_and_tx_index(changeset, block_with_next_tx_index) do
    %{block: block, next_tx_index: tx_index} = block_with_next_tx_index

    outputs =
      changeset.changes.outputs
      |> Enum.with_index()
      |> Enum.map(fn {output_changeset, output_index} ->
        position = %{output_id: Position.new(block.blknum, tx_index, output_index)}
        OutputChangeset.assign_position(output_changeset, position)
      end)

    changeset
    |> put_change(:tx_index, tx_index)
    |> put_assoc(:block, block)
    |> put_assoc(:outputs, outputs)
  end

  defp associate_paid_fees(changeset, paid_fees_by_currency) do
    paid_fees =
      Enum.map(paid_fees_by_currency, fn {currency, amount} ->
        PaidFee.changeset(%PaidFee{}, %{currency: currency, amount: amount})
      end)

    put_assoc(changeset, :paid_fees, paid_fees)
  end
end
