defmodule Engine.DB.Transaction.PaymentV1.ValidatorTest do
  use ExUnit.Case, async: true

  alias Engine.DB.Transaction.PaymentV1.Validator

  doctest Validator

  @alice <<1::160>>
  @bob <<2::160>>
  @token_1 <<1::160>>
  @token_2 <<2::160>>
  @fee %{@token_1 => [2, 10]}

  describe "validate/3" do
    test "successfuly validates a non-merge transaction with fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)
      i_3 = build_output(@token_2, 3, @alice)

      o_1 = build_output(@token_1, 2, @bob)
      o_2 = build_output(@token_2, 3, @bob)

      assert Validator.validate([i_1, i_2, i_3], [o_1, o_2], @fee) == :ok
    end

    test "rejects a non-merge transaction that doesn't include fees" do
      i_1 = build_output(@token_1, 2, @alice)
      o_1 = build_output(@token_1, 2, @bob)

      assert Validator.validate([i_1], [o_1], @fee) == {:error, {:inputs, :fees_not_covered}}
    end

    test "successfuly validates a merge transaction that doesn't include fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 4, @alice)

      assert Validator.validate([i_1, i_2], [o_1], @fee) == :ok
    end

    test "rejects a merge transaction that pays fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 2, @alice)

      assert Validator.validate([i_1, i_2], [o_1], @fee) == {:error, {:inputs, :overpaying_fees}}
    end
  end

  defp build_output(token, amount, output_guard) do
    %{output_guard: output_guard, token: token, amount: amount}
  end
end
