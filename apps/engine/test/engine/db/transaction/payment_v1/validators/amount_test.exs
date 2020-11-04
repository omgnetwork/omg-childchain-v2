defmodule Engine.DB.Transaction.PaymentV1.Validator.AmountTest do
  use ExUnit.Case, async: true

  alias Engine.DB.Transaction.PaymentV1.Validator.Amount

  doctest Amount

  @token_1 <<1::160>>
  @token_2 <<2::160>>
  @fee %{@token_1 => [2, 10]}

  describe "validate/3" do
    test "successfuly validates a valid transaction with fees" do
      assert Amount.validate(@fee, %{@token_1 => 2}) == :ok
    end

    test "successfuly validates a valid transaction without fees" do
      assert Amount.validate(:no_fees_required, %{}) == :ok
    end

    test "does not accept fee overpaying fees" do
      assert Amount.validate(@fee, %{@token_1 => 15}) == {:error, {:inputs, :overpaying_fees}}
    end

    test "returns a `overpaying_fees` error when paying fees for a transaction that does not require it" do
      assert Amount.validate(:no_fees_required, %{@token_1 => 2}) == {:error, {:inputs, :overpaying_fees}}
    end

    test "returns a `amounts_do_not_add_up` error when output amounts are greater than input amounts" do
      assert Amount.validate(@fee, %{@token_1 => -1}) == {:error, {:inputs, :amounts_do_not_add_up}}
    end

    test "returns a `amounts_do_not_add_up` error when multiple tokens are candidate for paying the fees" do
      assert Amount.validate(@fee, %{@token_1 => 1, @token_2 => 1}) == {:error, {:inputs, :amounts_do_not_add_up}}
    end

    test "returns a `fees_not_covered` error when no token are candidate for paying the fees" do
      assert Amount.validate(@fee, %{}) == {:error, {:inputs, :fees_not_covered}}
    end

    test "returns a `fees_not_covered` error when amount is not enough to cover the fees" do
      assert Amount.validate(@fee, %{@token_1 => 1}) == {:error, {:inputs, :fees_not_covered}}
    end

    test "returns a `fee_token_not_accepted` error when a token candidate is not supported as a fee token" do
      assert Amount.validate(@fee, %{@token_2 => 2}) == {:error, {:inputs, :fee_token_not_accepted}}
    end
  end
end
