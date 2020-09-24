defmodule Engine.DB.OutputTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Output, import: true

  alias Ecto.Changeset
  alias Engine.DB.Output

  describe "deposit/4" do
    test "returns a deposit changeset" do
      blknum = 1
      token = <<0::160>>
      depositor = <<1::160>>
      amount = 10

      changeset = Output.deposit(blknum, depositor, token, amount)

      assert changeset.valid?

      assert %Output{
               output_data: encoded_output_data,
               output_id: encoded_output_id,
               output_type: 1,
               position: position,
               state: :confirmed
             } = Changeset.apply_changes(changeset)

      assert %{output_data: %{amount: ^amount, output_guard: ^depositor, token: ^token}} =
               ExPlasma.Output.decode!(encoded_output_data)

      assert %{output_id: %{blknum: ^blknum, oindex: 0, position: 1_000_000_000, txindex: 0}} =
               ExPlasma.Output.decode_id!(encoded_output_id)
    end
  end

  describe "new/2" do
    test "returns a changeset for a new :pending output" do
      token = <<0::160>>
      output_guard = <<1::160>>
      amount = 10

      params = %{
        output_type: ExPlasma.payment_v1(),
        output_data: %{
          output_guard: output_guard,
          token: token,
          amount: amount
        }
      }

      changeset = Output.new(%Output{}, params)

      assert changeset.valid?

      assert %Output{
               output_data: encoded_output_data,
               output_id: nil,
               output_type: 1,
               position: nil,
               state: :pending
             } = Changeset.apply_changes(changeset)

      assert %{output_data: %{amount: ^amount, output_guard: ^output_guard, token: ^token}} =
               ExPlasma.Output.decode!(encoded_output_data)
    end
  end

  describe "spend/2" do
    test "returns a changeset with a state updated to :spent" do
      assert %{state: :confirmed} = output = insert(:deposit_output)

      changeset = Output.spend(output, %{})

      assert changeset.valid?
      assert %Output{state: :spent} = Changeset.apply_changes(changeset)
    end
  end

  describe "piggyback/2" do
    test "returns a changeset with a state updated to :piggybacked" do
      assert %{state: :confirmed} = output = insert(:deposit_output)

      changeset = Output.piggyback(output)

      assert changeset.valid?
      assert %Output{state: :piggybacked} = Changeset.apply_changes(changeset)
    end
  end

  describe "exit/2" do
    test "returns an updated multi with state of outputs for positions updated to :exiting" do
      %{position: p_1} = insert(:deposit_output)
      %{position: p_2} = :deposit_output |> insert() |> Output.spend(%{}) |> Engine.Repo.update!()
      :output |> insert() |> Output.piggyback() |> Repo.update!()
      insert(:deposit_output)

      multi = Output.exit(Ecto.Multi.new(), [p_1, p_2])
      assert Engine.Repo.transaction(multi) == {:ok, %{exiting_outputs: {1, nil}}}
    end
  end
end
