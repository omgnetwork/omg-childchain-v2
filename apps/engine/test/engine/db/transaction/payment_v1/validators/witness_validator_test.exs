defmodule Engine.DB.Transaction.PaymentV1.Validator.WitnessTest do
  use ExUnit.Case, async: true

  alias Engine.DB.Transaction.PaymentV1.Validator.Witness, as: WitnessValidator

  doctest WitnessValidator

  @alice <<1::160>>
  @bob <<2::160>>
  @token_1 <<1::160>>

  describe "validate/2" do
    test "returns :ok when input_guards match witnesses" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @bob)
      i_3 = build_output(@token_1, 3, @alice)

      assert WitnessValidator.validate([i_1, i_2, i_3], [@alice, @bob, @alice]) == :ok
    end

    test "returns an unauthorized_spend error when input_guards don't match witnesses" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @bob)
      i_3 = build_output(@token_1, 3, @alice)

      assert WitnessValidator.validate([i_1, i_2, i_3], [@alice, @bob, @bob]) ==
               {:error, {:witnesses, :unauthorized_spend}}
    end

    test "returns a missing_signature error when there is less witnesses than inputs" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @bob)
      i_3 = build_output(@token_1, 3, @alice)

      assert WitnessValidator.validate([i_1, i_2, i_3], [@alice, @bob]) == {:error, {:witnesses, :missing_signature}}
    end

    test "returns a superfluous_signature error when there is more witnesses than inputs" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @bob)

      assert WitnessValidator.validate([i_1, i_2], [@alice, @bob, @bob]) ==
               {:error, {:witnesses, :superfluous_signature}}
    end
  end

  defp build_output(token, amount, output_guard) do
    %{output_guard: output_guard, token: token, amount: amount}
  end
end
