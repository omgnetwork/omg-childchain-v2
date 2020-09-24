defmodule Engine.DB.Output.OutputChangesetTest do
  use Engine.DB.DataCase, async: true

  alias Ecto.Changeset
  alias Engine.DB.Output
  alias Engine.DB.Output.OutputChangeset
  alias ExPlasma.Output.Position

  describe "deposit/2" do
    test "generates a deposit changeset with input data, posision, output data and state" do
      params = %{
        state: :confirmed,
        output_type: ExPlasma.payment_v1(),
        output_data: %{
          output_guard: <<1::160>>,
          token: <<0::160>>,
          amount: 10
        },
        output_id: Position.new(1, 0, 0)
      }

      changeset = OutputChangeset.deposit(%Output{}, params)
      encoded_output_data = encoded_output_data(params)
      encoded_output_id = encoded_output_id(params)
      position = position(params)

      assert changeset.valid?

      assert %Output{
               output_data: ^encoded_output_data,
               output_id: ^encoded_output_id,
               output_type: 1,
               position: ^position,
               state: :confirmed
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "new/2" do
    test "generates a changeset for a new ouutput with output data and state" do
      params = %{
        state: :pending,
        output_type: ExPlasma.payment_v1(),
        output_data: %{
          output_guard: <<1::160>>,
          token: <<0::160>>,
          amount: 10
        }
      }

      changeset = OutputChangeset.new(%Output{}, params)
      encoded_output_data = encoded_output_data(params)

      assert changeset.valid?

      assert %Output{
               output_data: ^encoded_output_data,
               output_id: nil,
               output_type: 1,
               position: nil,
               state: :pending
             } = Changeset.apply_changes(changeset)
    end
  end

  describe "state/2" do
    test "generates a state change changeset" do
      assert %{state: :pending} = insert(:output)

      params = %{
        state: :confirmed
      }

      changeset = OutputChangeset.state(%Output{}, params)
      assert changeset.valid?

      assert %Output{
               state: :confirmed
             } = Changeset.apply_changes(changeset)
    end
  end

  defp encoded_output_data(params) do
    {:ok, encoded_output_data} =
      %ExPlasma.Output{}
      |> struct(params)
      |> ExPlasma.Output.encode()

    encoded_output_data
  end

  defp encoded_output_id(params) do
    {:ok, encoded_output_id} =
      %ExPlasma.Output{}
      |> struct(params)
      |> ExPlasma.Output.encode(as: :input)

    encoded_output_id
  end

  defp position(params), do: params.output_id.position
end
