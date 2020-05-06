defmodule Engine.FeeRulesTest do
  use Engine.DB.DataCase, async: true

  alias Ecto.Changeset
  alias Ecto.UUID
  alias Engine.DB.FeeRules

  describe "changeset/2" do
    test "casts given params" do
      params = %{data: %{"some" => "data"}, uuid: UUID.generate()}

      assert %Changeset{
               changes: params,
               valid?: true
             } = FeeRules.changeset(%FeeRules{}, params)
    end

    test "generates a uuid if not present" do
      params = %{data: %{"some" => "data"}}

      assert %Changeset{
               changes: %{uuid: uuid},
               valid?: true
             } = FeeRules.changeset(%FeeRules{}, params)

      assert UUID.cast(uuid) == {:ok, uuid}
    end
  end

  describe "fetch_latest/0" do
    test "fetches the latest record when present" do
      rules = insert(:fee_rules)

      assert FeeRules.fetch_latest() == {:ok, rules}
    end

    test "returns a `:not_found` error when not found" do
      assert FeeRules.fetch_latest() == {:error, :not_found}
    end
  end

  describe "insert_rules/1" do
    test "inserts the rules" do
      data = %{"some" => "data"}

      assert {:ok, %FeeRules{data: ^data}} = FeeRules.insert_rules(data)
    end
  end
end
