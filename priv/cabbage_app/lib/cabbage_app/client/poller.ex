defmodule CabbageApp.Client.Poller do
  @moduledoc """
  Functions to poll the network for certain state changes.
  """

  alias CabbageApp.Transactions.Encoding
  alias CabbageApp.Transactions.Tokens

  require Logger

  @sleep_retry_sec 1_000
  @retry_count 240

  @doc """
  Ethereum:: pull root chain account balance until succeeds. We're solving connection issues with this.
  """
  def wait_on_receipt_confirmed(receipt_hash),
    do: wait_on_receipt_status(receipt_hash, "0x1", @retry_count)

  @doc """
  Ethereum:: pull root chain account balance until succeeds. We're solving connection issues with this.
  """
  def root_chain_get_balance(address, currency \\ Tokens.ether()) do
    ether = Tokens.ether()

    case currency do
      ^ether ->
        root_chain_get_eth_balance(address, @retry_count)

      _ ->
        root_chain_get_erc20_balance(address, currency, @retry_count)
    end
  end

  defp wait_on_receipt_status(receipt_hash, _status, 0), do: get_transaction_receipt(receipt_hash)

  defp wait_on_receipt_status(receipt_hash, status, counter) do
    _ = Logger.info("Waiting on #{receipt_hash} for status #{status} for #{counter} seconds")
    do_wait_on_receipt_status(receipt_hash, status, counter)
  end

  defp do_wait_on_receipt_status(receipt_hash, expected_status, counter) do
    response = get_transaction_receipt(receipt_hash)
    # response might break with {:error, :closed} or {:error, :socket_closed_remotely}
    case response do
      {:ok, nil} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:error, _} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1)

      {:ok, %{"status" => ^expected_status} = resp} ->
        revert_reason(resp)
        resp

      {:ok, resp} ->
        revert_reason(resp)
        resp
    end
  end

  defp revert_reason(%{"status" => "0x1"}), do: :ok

  defp revert_reason(%{"status" => "0x0"} = response) do
    {:ok, tx} = Ethereumex.HttpClient.eth_get_transaction_by_hash(response["transactionHash"])

    {:ok, reason} =
      Ethereumex.HttpClient.eth_call(Map.put(tx, "data", tx["input"]), tx["blockNumber"])

    hash = response["transactionHash"]

    _ =
      Logger.info(
        "Revert reason for #{inspect(hash)}: revert string: #{inspect(decode_reason(reason))}, revert binary: #{
          inspect(CabbageApp.Transactions.Encoding.to_binary(reason), limit: :infinity)
        }"
      )
  end

  defp decode_reason(reason) do
    # https://ethereum.stackexchange.com/questions/48383/how-to-receive-revert-reason-for-past-transactions
    reason
    |> String.split_at(138)
    |> elem(1)
    |> Base.decode16!(case: :lower)
    |> String.chunk(:printable)
  end

  defp get_transaction_receipt(receipt_hash),
    do: Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash)

  defp root_chain_get_eth_balance(address, 0) do
    {:ok, initial_balance} = eth_account_get_balance(address)

    {initial_balance, ""} =
      initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)

    initial_balance
  end

  defp root_chain_get_eth_balance(address, counter) do
    response = eth_account_get_balance(address)

    case response do
      {:ok, initial_balance} ->
        {initial_balance, ""} =
          initial_balance |> String.replace_prefix("0x", "") |> Integer.parse(16)

        initial_balance

      _ ->
        Process.sleep(@sleep_retry_sec)
        root_chain_get_eth_balance(address, counter - 1)
    end
  end

  defp eth_account_get_balance(address) do
    Ethereumex.HttpClient.eth_get_balance(address)
  end

  defp root_chain_get_erc20_balance(address, currency, 0) do
    do_root_chain_get_erc20_balance(address, currency)
  end

  defp root_chain_get_erc20_balance(address, currency, counter) do
    case do_root_chain_get_erc20_balance(address, currency) do
      {:ok, balance} ->
        balance

      _ ->
        Process.sleep(@sleep_retry_sec)
        root_chain_get_erc20_balance(address, currency, counter - 1)
    end
  end

  defp do_root_chain_get_erc20_balance(address, currency) do
    data = ABI.encode("balanceOf(address)", [Encoding.to_binary(address)])

    case Ethereumex.HttpClient.eth_call(%{
           to: Encoding.to_hex(currency),
           data: Encoding.to_hex(data)
         }) do
      {:ok, result} ->
        balance =
          result
          |> Encoding.to_binary()
          |> ABI.TypeDecoder.decode([{:uint, 256}])
          |> hd()

        {:ok, balance}

      error ->
        error
    end
  end
end
