defmodule Engine.DB.OutputTest do
  use ExUnit.Case, async: true
  doctest Engine.DB.Output, import: true
  import Engine.Factory

  alias Engine.DB.Output

  describe "changeset/2" do
    test "populates the position column" do
      output_id =
        %{blknum: 1, txindex: 0, oindex: 0}
        |> ExPlasma.Output.Position.pos()
        |> ExPlasma.Output.Position.to_map()

      input = params_for(:input, output_id)
      changeset = Output.changeset(%Output{}, input)

      assert output_id.position == changeset.changes.output_id.position
    end
  end

  describe "usable/0" do
    #test "returns all confirmed and usable outputs"
  end
end
