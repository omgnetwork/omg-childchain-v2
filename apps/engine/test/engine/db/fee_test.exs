defmodule Engine.DB.FeeTest do
  use Engine.DB.DataCase, async: true

  alias Engine.DB.Fee

  @term %{
    1 => %{
      <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>> => %{
        amount: 43_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        subunit_to_unit: 1_000_000_000_000_000_000,
        type: :fixed,
        updated_at: ~U[2019-01-01 10:10:00Z]
      },
      <<17, 183, 89, 34, 116, 179, 68, 166, 190, 10, 206, 126, 93, 93, 244, 52, 132, 115, 226, 250>> => %{
        amount: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil,
        subunit_to_unit: 1_000_000_000_000_000_000,
        type: :fixed,
        updated_at: ~U[2019-01-01 10:10:00Z]
      }
    }
  }

  describe "insert/1" do
    test "inserts a new fees record" do
      params = %{term: @term, type: "current_fees"}

      {:ok, fees} = Fee.insert(params)

      assert fees.term == @term
      refute is_nil(fees.hash)
    end

    test "does not insert or updates a record if it was already inserted" do
      params = %{term: @term, type: "merged_fees"}

      {:ok, _fees1} = Fee.insert(params)
      {:ok, _fees2} = Fee.insert(params)

      assert Engine.Repo.aggregate(Fee, :count, :hash) == 1
    end

    test "does not insert a fee with an unknown type" do
      params = %{term: @term, type: "my_fees"}

      assert {:error, %{errors: errors}} = Fee.insert(params)

      assert errors == [
               type:
                 {"is invalid",
                  [
                    validation: :inclusion,
                    enum: ["previous_fees", "merged_fees", "current_fees"]
                  ]}
             ]
    end
  end

  describe "fetch_latest/0" do
    test "fetch the latest fees" do
      params1 = %{term: @term, type: "current_fees"}

      {:ok, _fees1} = Fee.insert(params1)

      Process.sleep(1_000)

      params2 = %{term: %{}, type: "current_fees"}

      {:ok, fees2} = Fee.insert(params2)

      assert Fee.fetch_latest() == {:ok, fees2}
    end

    test "return {:error, :not_found} if there is nothing in the table" do
      assert Fee.fetch_latest() == {:error, :not_found}
    end
  end
end
