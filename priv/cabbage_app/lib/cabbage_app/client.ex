defmodule CabbageApp.Client do
  @moduledoc false

  alias CabbageApp.Transactions.Deposit
  alias CabbageApp.Transactions.Encoding

  def deposit(amount_in_wei, output_address, vault_address, currency \\ Currency.ether()) do
    deposit_transaction = deposit_transaction(amount_in_wei, output_address, currency)
    value = if currency == Currency.ether(), do: amount_in_wei, else: 0
    data = ABI.encode("deposit(bytes)", [deposit_transaction])

    txmap = %{
      from: output_address,
      to: Encoding.to_hex(vault_address),
      value: Encoding.to_hex(value),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap)

    wait_on_receipt_confirmed(receipt_hash)
    {:ok, receipt_hash}
  end

  defp deposit_transaction(amount_in_wei, address, currency) do
    address
    |> Deposit.new(currency, amount_in_wei)
    |> Encoding.get_data_for_rlp()
    |> ExRLP.encode()
  end
end
