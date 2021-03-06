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
      params = %{term: @term, type: :current_fees}

      {:ok, fees} = Fee.insert(params)

      assert fees.term == @term
      assert fees.type == :current_fees
      refute is_nil(fees.hash)
    end

    # we may run multiple fee server instances which may insert the same fees
    # this test checks that we won't have race conditions
    test "does not insert or update a record if it was already inserted" do
      params = %{term: @term, type: :current_fees}
      inserted_at = DateTime.truncate(DateTime.utc_now(), :second)

      {:ok, _fees1} = params |> Map.put(:inserted_at, inserted_at) |> Fee.insert()
      {:ok, latest_fees_after_the_first_insert} = Fee.fetch_current_fees()

      {:ok, _fees2} = Fee.insert(params)
      {:ok, latest_fees_after_the_second_insert} = Fee.fetch_current_fees()

      assert Engine.Repo.aggregate(Fee, :count, :hash) == 1
      assert latest_fees_after_the_first_insert.inserted_at == inserted_at
      assert latest_fees_after_the_first_insert.inserted_at == latest_fees_after_the_second_insert.inserted_at
    end

    test "does not insert a fee with an unknown type" do
      params = %{term: @term, type: :my_fees}

      assert {:error, %{errors: errors}} = Fee.insert(params)

      assert errors == [
               type:
                 {"is invalid",
                  [
                    validation: :inclusion,
                    enum: [:previous_fees, :merged_fees, :current_fees]
                  ]}
             ]
    end
  end

  describe "fetch_current_fees/0" do
    test "fetches the latest fees" do
      params1 = %{term: @term, type: :current_fees}

      {:ok, _fees1} = Fee.insert(params1)

      params2 = %{
        term: %{dd: 11},
        type: :current_fees,
        inserted_at: DateTime.add(DateTime.utc_now(), 10_000_000, :second)
      }

      {:ok, fees2} = Fee.insert(params2)
      {:ok, latest_fees} = Fee.fetch_current_fees()

      assert latest_fees.hash == fees2.hash
    end

    test "return {:error, :not_found} if there is nothing in the table" do
      assert Fee.fetch_current_fees() == {:error, :not_found}
    end
  end

  describe "remove_previous_fees/0" do
    test "removes only previous fees" do
      params1 = %{term: @term, type: :current_fees}

      {:ok, _fees} = Fee.insert(params1)

      params2 = %{term: @term, type: :previous_fees}

      {:ok, _fees} = Fee.insert(params2)

      {1, nil} = Fee.remove_previous_fees()

      assert {:ok, %Fee{}} = Fee.fetch_current_fees()
      assert Fee.fetch_previous_fees() == {:error, :not_found}
    end

    test "calling it twice doesn't break anything" do
      params2 = %{term: @term, type: :previous_fees}

      {:ok, _fees} = Fee.insert(params2)

      assert {1, nil} = Fee.remove_previous_fees()
      assert {0, nil} = Fee.remove_previous_fees()
    end
  end
end
