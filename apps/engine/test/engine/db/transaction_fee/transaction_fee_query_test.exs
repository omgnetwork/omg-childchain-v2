defmodule Engine.DB.TransactionFee.TransactionFeeQueryTest do
  use Engine.DB.DataCase, async: false

  alias Engine.DB.TransactionFee.TransactionFeeQuery
  alias Engine.Repo

  describe "get_fees_for_block/1" do
    test "returns transaction fees by currency for a block" do
      eth = <<0::160>>
      other_token = <<1::160>>
      block1 = insert(:block, %{state: :finalizing})
      block2 = insert(:block, %{state: :finalizing})

      transaction1 = insert(:payment_v1_transaction, %{block: block1, tx_index: 0})
      _ = insert(:transaction_fee, %{transaction: transaction1, amount: 1, currency: eth})
      transaction2 = insert(:payment_v1_transaction, %{block: block1, tx_index: 1})
      _ = insert(:transaction_fee, %{transaction: transaction2, amount: 1, currency: eth})
      transaction3 = insert(:payment_v1_transaction, %{block: block1, tx_index: 2})
      _ = insert(:transaction_fee, %{transaction: transaction3, amount: 1, currency: other_token})

      transaction4 = insert(:payment_v1_transaction, %{block: block2})
      _ = insert(:transaction_fee, %{transaction: transaction4, amount: 1, currency: eth})

      expected = [{eth, Decimal.new(2)}, {other_token, Decimal.new(1)}]

      actual =
        block1.id
        |> TransactionFeeQuery.get_fees_for_block()
        |> Repo.all()

      assert actual == expected
    end
  end
end
