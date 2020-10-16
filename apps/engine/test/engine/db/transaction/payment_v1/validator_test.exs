defmodule Engine.DB.Transaction.PaymentV1.ValidatorTest do
  @moduledoc """
  This test module contains minimal testing of the Validator. Most of the logic is tested in nested validators.
  """
  use Engine.DB.DataCase, async: true

  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.PaymentV1.Validator

  @alice <<1::160>>
  @bob <<2::160>>
  @token_1 <<1::160>>
  @token_2 <<2::160>>
  @fee %{@token_1 => [2, 10]}

  describe "validate/2" do
    test "successfuly validates a non-merge transaction with fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)
      i_3 = build_output(@token_2, 3, @alice)

      o_1 = build_output(@token_1, 2, @bob)
      o_2 = build_output(@token_2, 3, @bob)

      changeset = build_changeset([i_1, i_2, i_3], [o_1, o_2], [@alice, @alice, @alice])

      validated_changeset = Validator.validate(changeset, @fee)

      assert validated_changeset.valid?
      assert validated_changeset == changeset
    end

    test "rejects a non-merge transaction that doesn't include fees" do
      i_1 = build_output(@token_1, 2, @alice)
      o_1 = build_output(@token_1, 2, @bob)

      changeset = build_changeset([i_1], [o_1], [@alice])

      validated_changeset = Validator.validate(changeset, @fee)

      refute validated_changeset.valid?
      assert "Fees are not covered by inputs" in errors_on(validated_changeset).inputs
    end

    test "successfuly validates a merge transaction that doesn't include fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 4, @alice)

      changeset = build_changeset([i_1, i_2], [o_1], [@alice, @alice])

      validated_changeset = Validator.validate(changeset, @fee)

      assert validated_changeset.valid?
      assert validated_changeset == changeset
    end

    test "rejects a merge transaction that pays fees" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @alice)

      o_1 = build_output(@token_1, 2, @alice)

      changeset = build_changeset([i_1, i_2], [o_1], [@alice, @alice])

      validated_changeset = Validator.validate(changeset, @fee)

      refute validated_changeset.valid?
      assert "Overpaying fees" in errors_on(validated_changeset).inputs
    end

    test "rejects a transaction when inputs are not signed by their owner" do
      i_1 = build_output(@token_1, 1, @alice)
      i_2 = build_output(@token_1, 3, @bob)

      o_1 = build_output(@token_1, 2, @alice)

      changeset = build_changeset([i_1, i_2], [o_1], [@alice, @alice])

      validated_changeset = Validator.validate(changeset, @fee)

      refute validated_changeset.valid?
      assert "Given signatures do not match the inputs owners" in errors_on(validated_changeset).witnesses
    end
  end

  defp build_output(token, amount, output_guard) do
    data = %{output_guard: output_guard, token: token, amount: amount}

    build(:output, %{output_data: data})
  end

  defp build_changeset(inputs, outputs, witnesses) do
    change(%Transaction{}, %{
      inputs: inputs,
      outputs: outputs,
      witnesses: witnesses
    })
  end
end
