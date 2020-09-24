defmodule API.V1.Controller.FeeControllerTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.FeeController

  describe "all/1" do
    test "returns fees" do
      insert(:current_fee)

      assert FeeController.all(%{}) ==
               {:ok,
                %{
                  "1" => [
                    %{
                      amount: 1,
                      currency: "0x0000000000000000000000000000000000000000",
                      pegged_amount: 1,
                      pegged_currency: "USD",
                      pegged_subunit_to_unit: 100,
                      subunit_to_unit: 1_000_000_000_000_000_000,
                      updated_at: ~U[2019-01-01 10:00:00Z]
                    },
                    %{
                      amount: 2,
                      currency: "0x0000000000000000000000000000000000000001",
                      pegged_amount: 1,
                      pegged_currency: "USD",
                      pegged_subunit_to_unit: 100,
                      subunit_to_unit: 1_000_000_000_000_000_000,
                      updated_at: ~U[2019-01-01 10:00:00Z]
                    }
                  ],
                  "2" => [
                    %{
                      amount: 2,
                      currency: "0x0000000000000000000000000000000000000000",
                      pegged_amount: 1,
                      pegged_currency: "USD",
                      pegged_subunit_to_unit: 100,
                      subunit_to_unit: 1_000_000_000_000_000_000,
                      updated_at: ~U[2019-01-01 10:00:00Z]
                    }
                  ]
                }}
    end

    test "filters fees" do
      insert(:current_fee)

      assert FeeController.all(%{"tx_types" => [1]}) == {
               :ok,
               %{
                 "1" => [
                   %{
                     amount: 1,
                     currency: "0x0000000000000000000000000000000000000000",
                     pegged_amount: 1,
                     pegged_currency: "USD",
                     pegged_subunit_to_unit: 100,
                     subunit_to_unit: 1_000_000_000_000_000_000,
                     updated_at: ~U[2019-01-01 10:00:00Z]
                   },
                   %{
                     amount: 2,
                     currency: "0x0000000000000000000000000000000000000001",
                     pegged_amount: 1,
                     pegged_currency: "USD",
                     pegged_subunit_to_unit: 100,
                     subunit_to_unit: 1_000_000_000_000_000_000,
                     updated_at: ~U[2019-01-01 10:00:00Z]
                   }
                 ]
               }
             }
    end
  end
end
