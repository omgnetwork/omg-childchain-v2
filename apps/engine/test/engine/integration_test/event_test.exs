defmodule EventTest do
  use ExUnit.Case, async: true

  alias Engine.Configuration
  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.RootChain.Event
  alias Engine.Geth
  alias ExPlasma.Encoding

  @moduletag :integration
  @gas 180_000

  setup_all do
    {:ok, _ethereumex} = Application.ensure_all_started(:ethereumex)
    port = Enum.random(35_000..40_000)
    {:ok, {_geth_pid, _container_id}} = Geth.start(port)
    :ets.new(:events_bucket_test, [:bag, :public, :named_table])
    url = "http://127.0.0.1:#{port}"
    contracts = Configuration.contracts()

    {:ok, pid} =
      start_supervised(
        {Aggregator,
         opts: [url: url],
         contracts: contracts,
         ets: :events_bucket_test,
         events: [
           [name: :deposit_created, enrich: false],
           [name: :in_flight_exit_started, enrich: true],
           [name: :in_flight_exit_input_piggybacked, enrich: false],
           [name: :in_flight_exit_output_piggybacked, enrich: false],
           [name: :exit_started, enrich: true]
         ]}
      )

    %{pid: pid, port: port}
  end

  test "deposit is recognized by the aggregator", %{pid: pid, port: port} do
    deposit(port)
    {:ok, [deposit]} = Aggregator.deposit_created(pid, 1, 6000)

    assert deposit == %Event{
             eth_height: deposit.eth_height,
             event_signature: "DepositCreated(address,uint256,address,uint256)",
             log_index: 0,
             root_chain_tx_hash: deposit.root_chain_tx_hash,
             call_data: nil,
             data: %{
               "amount" => 1_000_000,
               "blknum" => 1,
               "depositor" =>
                 <<109, 228, 179, 185, 194, 142, 156, 62, 132, 194, 178, 211, 168, 117, 201, 71, 168, 77, 230, 141>>,
               "token" => <<0::160>>
             }
           }
  end

  defp deposit(port) do
    opts = [url: "http://127.0.0.1:#{port}"]
    vault_address = Configuration.eth_vault()
    {:ok, [output_address | _]} = Ethereumex.HttpClient.eth_accounts(opts)
    {:ok, true} = Ethereumex.HttpClient.request("personal_unlockAccount", [output_address, "", 0], opts)
    amount_in_wei = 1_000_000
    currency = ether()

    deposit_transaction = deposit_transaction(amount_in_wei, output_address, currency)

    data = ABI.encode("deposit(bytes)", [deposit_transaction])

    txmap = %{
      from: output_address,
      to: vault_address,
      value: Encoding.to_hex(amount_in_wei),
      data: Encoding.to_hex(data),
      gas: Encoding.to_hex(@gas)
    }

    {:ok, receipt_hash} = Ethereumex.HttpClient.eth_send_transaction(txmap, opts)

    Poller.wait_on_receipt_confirmed(receipt_hash, opts)
    {:ok, receipt_hash}
  end

  def ether(), do: <<0::160>>

  defp deposit_transaction(amount_in_wei, address, currency) do
    address
    |> Deposit.new(currency, amount_in_wei)
    |> get_data_for_rlp()
    |> ExRLP.encode()
  end

  defp get_data_for_rlp(deposit) do
    [ExPlasma.payment_v1(), deposit.inputs, deposit.outputs, 0, deposit.metadata]
  end
end
