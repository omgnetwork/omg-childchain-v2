defmodule Engine.Fee.FeeClaimTest do
  @moduledoc false

  use Engine.DB.DataCase, async: false

  alias Engine.Fee.FeeClaim

  @alice <<1::160>>
  @bob <<2::160>>

  @eth <<0::160>>
  @token_1 <<5::160>>
  @token_2 <<6::160>>

  describe "fee_paid/2" do
    test "returns a map of positive amounts for each token" do
      # @alice pays 3 @eth to @bob
      # @alice pays 1 @eth of fees
      # @alice get 1 @eth back
      # @alice pays 4 @token_1 of fees
      # @alice pays 5 @token_2 to @bob

      # Note: in the current childchain, we don't accept paying fees in more than one token
      # but the module we are testing is not aware of this.
      input_data = [
        output_data(@alice, @eth, 2),
        output_data(@alice, @eth, 3),
        output_data(@alice, @token_1, 4),
        output_data(@alice, @token_2, 5)
      ]

      output_data = [
        output_data(@bob, @eth, 3),
        output_data(@alice, @eth, 1),
        output_data(@bob, @token_2, 5)
      ]

      assert FeeClaim.paid_fees(input_data, output_data) == %{
               @eth => 1,
               @token_1 => 4
             }
    end
  end

  defp output_data(owner, token, amount) do
    %{
      output_guard: owner,
      token: token,
      amount: amount
    }
  end
end
