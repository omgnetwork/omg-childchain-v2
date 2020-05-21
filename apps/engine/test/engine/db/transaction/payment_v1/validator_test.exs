defmodule Engine.DB.Transaction.PaymentV1.ValidatorTest do
  use ExUnit.Case, async: true

  alias Engine.DB.Transaction.PaymentV1.Validator

  doctest Validator

  @alice <<1::160>>
  @bob <<2::160>>
  @token_1 <<1::160>>
  @token_2 <<2::160>>
  @token_3 <<3::160>>
  @fee %{@token_1 => [2, 10]}

  describe "validate/3" do
    test "successfuly validates a valid transaction with fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)
      i_3 = build_output(@token_2, 3, @alice)
      i_4 = build_output(@token_3, 4, @alice)

      o_1 = build_output(@token_1, 2, @bob)
      o_2 = build_output(@token_2, 3, @bob)
      o_3 = build_output(@token_3, 4, @bob)

      assert Validator.validate([i_1, i_2, i_3, i_4], [o_1, o_2, o_3], @fee) == {:ok, nil}
    end

    test "successfuly validates a valid transaction without fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 2, @alice)
      i_3 = build_output(@token_1, 3, @alice)
      i_4 = build_output(@token_1, 4, @alice)

      o_1 = build_output(@token_1, 10, @alice)

      assert Validator.validate([i_1, i_2, i_3, i_4], [o_1], :no_fees_required) == {:ok, nil}
    end

    test "accepts any amount of fee given it's a valid fee amount" do
      i_1 = build_output(@token_1, 15, @alice)

      o_1 = build_output(@token_1, 5, @bob)

      assert Validator.validate([i_1], [o_1], @fee) == {:ok, nil}
    end

    test "returns a `overpaying_fees` error when paying fees for a transaction that does not require it" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 2, @alice)

      assert Validator.validate([i_1, i_2], [o_1], :no_fees_required) == {:error, {:inputs, :overpaying_fees}}
    end

    test "returns a `amounts_do_not_add_up` error when output amounts are greater than input amounts" do
      i_1 = build_output(@token_1, 1, @alice)
      o_1 = build_output(@token_1, 2, @bob)

      assert Validator.validate([i_1], [o_1], @fee) == {:error, {:inputs, :amounts_do_not_add_up}}
    end

    test "returns a `amounts_do_not_add_up` error when multiple tokens are candidate for paying the fees" do
      i_1 = build_output(@token_1, 2, @alice)
      i_2 = build_output(@token_2, 2, @alice)
      o_1 = build_output(@token_1, 1, @bob)
      o_2 = build_output(@token_2, 1, @bob)

      assert Validator.validate([i_1, i_2], [o_1, o_2], @fee) == {:error, {:inputs, :amounts_do_not_add_up}}
    end

    test "returns a `fees_not_covered` error when no token are candidate for paying the fees" do
      i_1 = build_output(@token_1, 2, @alice)
      i_2 = build_output(@token_2, 2, @alice)
      o_1 = build_output(@token_1, 2, @bob)
      o_2 = build_output(@token_2, 2, @bob)

      assert Validator.validate([i_1, i_2], [o_1, o_2], @fee) == {:error, {:inputs, :fees_not_covered}}
    end

    test "returns a `fees_not_covered` error when there is a token candidate but amount does not cover the fees" do
      i_1 = build_output(@token_1, 2, @alice)
      o_1 = build_output(@token_1, 2, @bob)

      assert Validator.validate([i_1], [o_1], @fee) == {:error, {:inputs, :fees_not_covered}}
    end

    test "returns a `fee_token_not_accepted` error when a token candidate is not supported as a fee token" do
      i_1 = build_output(@token_1, 2, @alice)
      i_2 = build_output(@token_2, 2, @alice)
      o_1 = build_output(@token_1, 1, @bob)
      o_2 = build_output(@token_2, 2, @bob)

      assert Validator.validate([i_1, i_2], [o_1, o_2], @fee) == {:error, {:inputs, :fees_not_covered}}
    end
  end

  defp build_output(token, amount, output_guard) do
    %{output_guard: output_guard, token: token, amount: amount}
  end
end
