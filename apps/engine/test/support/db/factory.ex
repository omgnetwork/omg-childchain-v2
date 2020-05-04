defmodule Engine.DB.Factory do
  @moduledoc """
  Factories for our Ecto Schemas.
  """

  use ExMachina.Ecto, repo: Engine.Repo

  import Ecto.Changeset
  import Ecto.Query

  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias ExPlasma.Builder
  alias ExPlasma.Output.Position

  def deposit_transaction_factory(attr \\ %{}) do
    # Pick an available block number.
    blknum = (Engine.Repo.one(from(b in Block, select: b.number)) || 0) + 1
    output_guard = Map.get(attr, :output_guard) || <<1::160>>
    amount = Map.get(attr, :amount, 1)
    data = %{output_guard: output_guard, token: <<0::160>>, amount: amount}

    id =
      %{blknum: blknum, txindex: 0, oindex: 0}
      |> Position.pos()
      |> Position.to_map()

    tx_bytes =
      [tx_type: 1]
      |> Builder.new()
      |> Builder.add_output(output_guard: output_guard, token: <<0::160>>, amount: amount)
      |> ExPlasma.encode()

    output =
      :output
      |> build(output_id: id, output_data: data, output_type: 1)
      |> set_state("confirmed")

    %Transaction{
      tx_bytes: tx_bytes,
      tx_hash: ExPlasma.hash(tx_bytes),
      outputs: [output],
      block: %Block{state: "confirmed", number: blknum}
    }
  end

  def payment_v1_transaction_factory(attr) do
    [tx_type: 1]
    |> Builder.new()
    |> Builder.add_input(blknum: Map.get(attr, :blknum, 1), txindex: 0, oindex: 0)
    |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
    |> ExPlasma.encode()
    |> Transaction.decode()
    |> apply_changes()
  end

  # The "lowest" unit in the hierarchy. This is made to form into transactions
  def output_factory(attr \\ %{}) do
    %Output{}
    |> Output.changeset(%{
      output_type: Map.get(attr, :output_type, 1),
      output_id: Map.get(attr, :output_id),
      output_data: Map.get(attr, :output_data)
    })
    |> apply_changes()
  end

  def spent(%Transaction{outputs: [output]} = txn), do: %{txn | outputs: [%{output | state: "spent"}]}

  def set_state(%Transaction{outputs: [output]}, state), do: %{output | state: state}
  def set_state(%Output{} = output, state), do: %{output | state: state}
end
