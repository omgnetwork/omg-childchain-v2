defmodule Engine.Feefeed.Fees.Calculator.FlatFeeTest do
  use ExUnit.Case, async: true

  alias Engine.Feefeed.Fees.Calculator.FlatFee

  describe "calculate/2" do
    test "calculates fees of fixed type correctly" do
      currency_rules = %{
        type: "fixed",
        symbol: "ETH",
        amount: 43_000_000_000_000,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_amount: nil,
        pegged_currency: nil,
        pegged_subunit_to_unit: nil
      }

      # For fixed type fees, the fees are the same as the rules
      assert FlatFee.calculate(currency_rules, []) == {:ok, currency_rules}
    end
  end
end
