defmodule Engine.DB.Transaction.PaymentV1.MergeValidatorTest do
  use ExUnit.Case, async: true

  alias Engine.DB.Transaction.PaymentV1.MergeValidator

  doctest MergeValidator

  @alice <<1::160>>
  @bob <<2::160>>
  @token_1 <<1::160>>
  @token_2 <<2::160>>

  describe "is_merge?/2" do
    test "returns true when has less outputs than inputs, has single currency, and has same account" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 4, @alice)

      assert MergeValidator.is_merge?([i_1, i_2], [o_1])
    end

    test "returns false when has as many outputs than inputs" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 2, @alice)
      o_2 = build_output(@token_1, 2, @alice)

      refute MergeValidator.is_merge?([i_1, i_2], [o_1, o_2])
    end

    test "returns false when has more outputs than inputs" do
      i_1 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 1, @alice)
      o_2 = build_output(@token_1, 2, @alice)

      refute MergeValidator.is_merge?([i_1], [o_1, o_2])
    end

    test "returns false when has more than 1 currency" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)
      i_3 = build_output(@token_2, 4, @alice)

      o_1 = build_output(@token_1, 4, @alice)
      o_2 = build_output(@token_2, 4, @alice)

      refute MergeValidator.is_merge?([i_1, i_2, i_3], [o_1, o_2])
    end

    test "returns false when has more than 1 account" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 4, @bob)

      refute MergeValidator.is_merge?([i_1, i_2], [o_1])
    end
  end

  defp build_output(token, amount, output_guard) do
    %{output_guard: output_guard, token: token, amount: amount}
  end
end
