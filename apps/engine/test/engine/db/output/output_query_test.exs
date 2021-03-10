defmodule Engine.DB.Output.OutputQueryTest do
  use Engine.DB.DataCase, async: true

  alias Engine.DB.Output
  alias Engine.DB.Output.OutputQuery
  alias Engine.Repo

  describe "usable_for_positions/1" do
    test "returns :confirmed output without a spending_transaction and with matching position" do
      %{position: p_1} = insert(:deposit_output)
      %{position: p_2} = :deposit_output |> insert() |> Output.spend() |> Engine.Repo.update!()
      :output |> insert() |> Output.piggyback() |> Repo.update!()
      insert(:deposit_output)

      assert [%{position: ^p_1}] = [p_1, p_2] |> OutputQuery.usable_for_positions() |> Repo.all()
    end
  end
end
