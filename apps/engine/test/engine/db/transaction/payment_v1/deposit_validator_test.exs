defmodule Engine.DB.Transaction.PaymentV1.DepositValidatorTest do
  use ExUnit.Case, async: true

  alias Engine.DB.Transaction.PaymentV1.DepositValidator

  doctest DepositValidator

  @alice <<1::160>>
  @token_1 <<1::160>>

  describe "validate/3" do
    test "successfuly validates a valid deposit" do
      output = build_output(@token_1, 2, @alice)

      assert DepositValidator.validate([], [output], %{}) == :ok
    end

    test "raises an error when inputs are not empty" do
      input = build_output(@token_1, 2, @alice)
      output = build_output(@token_1, 2, @alice)

      assert_raise ArgumentError, "deposits should not have inputs", fn ->
        DepositValidator.validate([input], [output], %{})
      end
    end

    test "raises an error when outputs are empty" do
      assert_raise ArgumentError, "deposit should have 1 output only", fn ->
        DepositValidator.validate([], [], %{})
      end
    end

    test "raises an error when there is more than 1 output" do
      o_1 = build_output(@token_1, 2, @alice)
      o_2 = build_output(@token_1, 2, @alice)

      assert_raise ArgumentError, "deposit should have 1 output only", fn ->
        DepositValidator.validate([], [o_1, o_2], %{})
      end
    end
  end

  defp build_output(token, amount, output_guard) do
    %{output_guard: output_guard, token: token, amount: amount}
  end
end
