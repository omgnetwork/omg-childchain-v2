defmodule Engine.Feefeed.Fees.CalculatorTest do
  use Engine.DB.DataCase, async: true

  alias Engine.Feefeed.Fees.Calculator

  describe "calculate/2" do
    test "calculates fees of fixed type correctly" do
      %{data: rules} = insert(:fee_rules)

      # For fixed type fees, the fees are the same as the rules
      assert Calculator.calculate(rules) == {:ok, rules}
    end

    test "returns an error if an invalid type was given" do
      rules =
        :fee_rules
        |> params_for()
        |> Kernel.put_in(
          [:data, "1", "0x0000000000000000000000000000000000000000", "type"],
          "invalid"
        )
        |> Map.fetch!(:data)

      assert Calculator.calculate(rules) ==
               {:error, :unsupported_fee_type, "got: 'invalid', which is not currently supported"}
    end
  end
end
