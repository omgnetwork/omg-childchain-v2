defmodule API.V1.Controller.FeeTest do
  use Engine.DB.DataCase, async: true

  alias API.V1.Controller.Fee

  setup_all do
    fee_specs = %{
      1 => %{
        Base.decode16!("0000000000000000000000000000000000000000") => %{
          amount: 1,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_unix!(1_546_336_800)
        },
        Base.decode16!("0000000000000000000000000000000000000001") => %{
          amount: 2,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_unix!(1_546_336_800)
        }
      },
      2 => %{
        Base.decode16!("0000000000000000000000000000000000000000") => %{
          amount: 2,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 100,
          updated_at: DateTime.from_unix!(1_546_336_800)
        }
      }
    }

    params = [term: fee_specs, type: :current_fees]

    _ = insert(:fee, params)

    :ok
  end

  describe "all/1" do
    test "returns fees" do
      assert {:ok,
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
              }} == Fee.all(%{})
    end

    test "filters fees" do
      assert {
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
             } ==
               Fee.all(%{"tx_types" => [1]})
    end
  end
end
