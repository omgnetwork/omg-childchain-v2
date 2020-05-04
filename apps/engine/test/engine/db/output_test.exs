defmodule Engine.DB.OutputTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Output, import: true
  import Engine.DB.Factory

  alias ExPlasma.Output.Position

  describe "changeset/2" do
    test "populates the position column" do
      output_id = %{blknum: 1, txindex: 0, oindex: 0} |> Position.pos() |> Position.to_map()
      output = build(:output, output_id: output_id)

      assert output_id.position == output.position
    end

    test "encodes the output_data" do
      data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: 1}
      params = %ExPlasma.Output{output_id: nil, output_data: data, output_type: 1}
      encoded = ExPlasma.Output.encode(params)

      output = build(:output, output_data: data)

      assert encoded == output.output_data
    end

    test "encodes the output_id" do
      output_id = %{blknum: 1, txindex: 0, oindex: 0} |> Position.pos() |> Position.to_map()
      encoded = ExPlasma.Output.encode(%ExPlasma.Output{output_id: output_id}, as: :input)
      output = build(:output, output_id: output_id)

      assert encoded == output.output_id
    end
  end
end
