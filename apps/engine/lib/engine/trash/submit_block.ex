defmodule Engine.Trash.SubmitBlock do
  @moduledoc """
  Interface to contract block submission.
  """
  alias Engine.Trash.Blockchain.PrivateKey
  alias Engine.Trash.Blockchain.Transaction
  alias Engine.Trash.Blockchain.Transaction.Signature
  alias ExPlasma.Encoding

  @type address :: <<_::160>>
  @type hash :: <<_::256>>

  def submit(hash, nonce, gas_price, contract, opts) do
    # NOTE: we're not using any defaults for opts here!
    contract_transact(contract, "submitBlock(bytes32)", [hash], nonce, gas_price, 0, 100_000, opts)
  end

  defp contract_transact(contract, signature, args, nonce, gas_price, value, gas_limit, opts) do
    abi_encoded_data = ABI.encode(signature, args)
    private_key = PrivateKey.get()

    transaction_data =
      %Transaction{
        data: abi_encoded_data,
        gas_limit: gas_limit,
        gas_price: gas_price,
        init: <<>>,
        nonce: nonce,
        to: contract,
        value: value
      }
      |> Signature.sign_transaction(private_key)
      |> Transaction.serialize()
      |> ExRLP.encode()
      |> Base.encode16(case: :lower)

    transact("0x" <> transaction_data, opts)
  end

  defp transact(transaction_data, opts) do
    case Ethereumex.HttpClient.eth_send_raw_transaction(transaction_data, opts) do
      {:ok, receipt_enc} -> {:ok, Encoding.to_binary(receipt_enc)}
      other -> other
    end
  end
end
