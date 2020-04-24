defmodule Engine.DB.OutputTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Output, import: true
  import Engine.DB.Factory

  alias Engine.DB.Output

  describe "changeset/2" do
    test "populates the position column" do
      output_id =
        %{blknum: 1, txindex: 0, oindex: 0}
        |> ExPlasma.Output.Position.pos()
        |> ExPlasma.Output.Position.to_map()

      input = %{output_type: 1, output_id: output_id, output_data: nil}
      changeset = Output.changeset(%Output{}, input)

      assert output_id.position == changeset.changes.position
    end

    test "encodes the output_data" do
      data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: 1}
      params = %{output_id: nil, output_data: data, output_type: 1}
      encoded = ExPlasma.Output.encode(params)
      changeset = Output.changeset(%Output{}, params)

      assert encoded == changeset.changes.output_data
    end

    test "encodes the output_id" do
      output_id =
        %{blknum: 1, txindex: 0, oindex: 0}
        |> ExPlasma.Output.Position.pos()
        |> ExPlasma.Output.Position.to_map()

      encoded = ExPlasma.Output.encode(%{output_id: output_id}, as: :input)
      params = %{output_type: 1, output_id: output_id, output_data: nil}
      changeset = Output.changeset(%Output{}, params)

      assert encoded == changeset.changes.output_id
    end
  end

  describe "usable/0" do
    #test "returns all confirmed and usable outputs"
  end
end
