defmodule API.V1.FeesTest do
  use ExUnit.Case, async: true

  alias API.V1.Fees

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

    _ = if :undefined == :ets.info(:fees_bucket), do: :ets.new(:fees_bucket, [:set, :public, :named_table])
    true = :ets.insert(:fees_bucket, [{:fees, fee_specs}])

    %{}
  end

  describe "all/1" do
    test "filters the result when given currencies" do
      assert %{
               "1" => [
                 %{
                   "amount" => 1,
                   "currency" => "0x0000000000000000000000000000000000000000",
                   "subunit_to_unit" => 1_000_000_000_000_000_000,
                   "pegged_amount" => 1,
                   "pegged_currency" => "USD",
                   "pegged_subunit_to_unit" => 100,
                   "updated_at" => "2019-01-01T10:00:00Z"
                 }
               ],
               "2" => [
                 %{
                   "amount" => 2,
                   "currency" => "0x0000000000000000000000000000000000000000",
                   "subunit_to_unit" => 1_000_000_000_000_000_000,
                   "pegged_amount" => 1,
                   "pegged_currency" => "USD",
                   "pegged_subunit_to_unit" => 100,
                   "updated_at" => "2019-01-01T10:00:00Z"
                 }
               ]
             } = Fees.all(%{currencies: ["0x0000000000000000000000000000000000000000"]})
    end
  end
end
