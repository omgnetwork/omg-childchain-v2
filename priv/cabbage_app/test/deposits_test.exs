defmodule DepositsTests do
  use Cabbage.Feature, async: true, file: "deposits.feature"

  alias CabbageApp.Accounts

  setup do
    [{alice_account, alice_pkey}, {bob_account, _bob_pkey}] = Accounts.take_accounts(2)

    %{alice_account: alice_account, alice_pkey: alice_pkey, bob_account: bob_account, gas: 0}
  end

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          %{alice_account: alice_account} = state do
    initial_balance = Itest.Poller.root_chain_get_balance(alice_account)

    {:ok, receipt_hash} =
      Reorg.execute_in_reorg(fn ->
        amount
        |> Currency.to_wei()
        |> Client.deposit(alice_account, Itest.PlasmaFramework.vault(Currency.ether()))
      end)

    gas_used = Client.get_gas_used(receipt_hash)

    {_, new_state} =
      Map.get_and_update!(state, :gas, fn current_gas ->
        {current_gas, current_gas + gas_used}
      end)

    state =
      new_state
      |> Map.put_new(:alice_initial_balance, initial_balance)
      |> Map.put(:deposit_transaction_hash, receipt_hash)

    {:ok, state}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end

  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end

  defthen ~r/^Alice should have the root chain balance changed by "(?<amount>[^"]+)" ETH$/,
          %{amount: amount},
          state do
    {:ok, state}
  end

  defthen ~r/^Bob should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end
end
