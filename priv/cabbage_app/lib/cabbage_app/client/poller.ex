defmodule CabbageApp.Client.Poller do
  @moduledoc """
  Functions to poll the network for certain state changes.
  """

  require Logger

  @sleep_retry_sec 1_000
  @retry_count 240

  def wait_on_receipt_confirmed(receipt_hash),
    do: wait_on_receipt_status(receipt_hash, "0x1", @retry_count)

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
end
