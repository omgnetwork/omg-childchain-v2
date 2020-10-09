defmodule Engine.Fee.FeeClaimTest do
  @moduledoc false

  use Engine.DB.DataCase, async: true

  alias Engine.Fee.FeeClaim
  alias ExPlasma.Transaction.Type.Fee, as: ExPlasmaFee

  @alice <<1::160>>
  @bob <<2::160>>
  @fee_claimer <<3::160>>

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

      assert FeeClaim.fee_paid(input_data, output_data) == %{
               @eth => 1,
               @token_1 => 4
             }
    end
  end

  describe "generate_fee_transactions/2" do
    test "returns correct fee transactions" do
      # fee: 2 @eth
      t_1_i_1 = insert(:output, %{output_data: output_data(@alice, @eth, 5)})
      t_1_o_1 = insert(:output, %{output_data: output_data(@bob, @eth, 3)})

      # fee: 1 @eth & 1 @token_1
      t_2_i_1 = insert(:output, %{output_data: output_data(@alice, @eth, 2)})
      t_2_i_2 = insert(:output, %{output_data: output_data(@alice, @token_1, 2)})
      t_2_o_1 = insert(:output, %{output_data: output_data(@bob, @eth, 1)})
      t_2_o_2 = insert(:output, %{output_data: output_data(@bob, @token_1, 1)})

      # fee: 1 @eth
      t_3_i_1 = insert(:output, %{output_data: output_data(@alice, @eth, 2)})
      t_3_o_1 = insert(:output, %{output_data: output_data(@bob, @eth, 1)})

      t_1 = insert(:payment_v1_transaction, %{inputs: [t_1_i_1], outputs: [t_1_o_1]})
      t_2 = insert(:payment_v1_transaction, %{inputs: [t_2_i_1, t_2_i_2], outputs: [t_2_o_1, t_2_o_2]})
      t_3 = insert(:payment_v1_transaction, %{inputs: [t_3_i_1], outputs: [t_3_o_1]})

      block = insert(:block, %{transactions: [t_1, t_2, t_3]})

      assert [fee_tx_1, fee_tx_2] = FeeClaim.generate_fee_transactions(block, @fee_claimer)

      assert {:ok,
              %{
                tx_type: 3,
                inputs: [],
                nonce: fee_nonce_1,
                outputs: [fee_output_1]
              }} = ExPlasma.decode(fee_tx_1)

      assert {:ok,
              %{
                tx_type: 3,
                inputs: [],
                nonce: fee_nonce_2,
                outputs: [fee_output_2]
              }} = ExPlasma.decode(fee_tx_2)

      assert {:ok, ^fee_nonce_1} = ExPlasmaFee.build_nonce(%{blknum: block.blknum, token: @eth})
      assert {:ok, ^fee_nonce_2} = ExPlasmaFee.build_nonce(%{blknum: block.blknum, token: @token_1})

      assert %{
               output_data: %{
                 amount: 4,
                 output_guard: @fee_claimer,
                 token: @eth
               },
               output_type: 2
             } = fee_output_1

      assert %{
               output_data: %{
                 amount: 1,
                 output_guard: @fee_claimer,
                 token: @token_1
               },
               output_type: 2
             } = fee_output_2
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
