defmodule Engine.DB.Factory do
  @moduledoc """
  Factories for our Ecto Schemas.
  """

  use ExMachina.Ecto, repo: Engine.Repo

  alias Engine.DB.Block
  alias Engine.DB.Transaction
  alias Engine.DB.Output

  import Ecto.Changeset
  import Ecto.Query

  def deposit_transaction_factory(attr \\ %{}) do
    # Pick an available block number.
    blknum = (Engine.Repo.one(from(b in Block, select: b.number)) || 0) + 1
    amount = Map.get(attr, :amount, 1)
    data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: amount}

    id = 
      %{blknum: blknum, txindex: 0, oindex: 0}
      |> ExPlasma.Output.Position.pos()
      |> ExPlasma.Output.Position.to_map()

    txbytes = new_txn() |> add_output(data) |> ExPlasma.encode()

    output = 
      :output
      |> build(output_id: id, output_data: data, output_type: 1)
      |> set_state("confirmed")

    %Transaction{
      txbytes: txbytes,
      outputs: [output],
      block: %Block{state: "confirmed", number: blknum}
    }
  end

  def payment_v1_transaction_factory(attr) do
    id = 
      %{blknum: Map.get(attr, :blknum, 1), txindex: 0, oindex: 0}
      |> ExPlasma.Output.Position.pos()
      |> ExPlasma.Output.Position.to_map()

    input = Engine.Repo.one(Output.usable()) || 
      params_for(:output, output_id: id)

    data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: 1}

    new_txn() 
    |> add_input(input.output_id)
    |> add_output(data)
    |> ExPlasma.encode()
    |> Transaction.decode_changeset()
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

  defp new_txn(), do: %ExPlasma.Transaction{tx_type: 1}

  # position_map is %{blknum: 1, txindex: 0, oindex: 0}
  defp add_input(ex_txn, %{} = position_map) do
    output_id = 
      position_map
      |> ExPlasma.Output.Position.pos()
      |> ExPlasma.Output.Position.to_map()

    input = %ExPlasma.Output{output_id: output_id}

    %{ex_txn | inputs: [input] ++ ex_txn.inputs }
  end

  defp add_input(ex_txn, encoded) do
    input = ExPlasma.Output.decode_id(encoded)
    %{ex_txn | inputs: [input] ++ ex_txn.inputs}
  end

  defp add_output(ex_txn, %{} = output_data) do
    output = %ExPlasma.Output{output_type: 1, output_data: output_data}
    %{ex_txn | outputs: [output] ++ ex_txn.outputs }
  end
end
