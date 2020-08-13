defmodule Poller do
  @moduledoc """
    Geth poller for anything that just takes time...
  """
  alias ExPlasma.Encoding
  require Logger

  @sleep_retry_sec 1_000
  @retry_count 30

  def wait_on_receipt_confirmed(receipt_hash, opts) do
    wait_on_receipt_status(receipt_hash, "0x1", @retry_count, opts)
  end

  defp wait_on_receipt_status(receipt_hash, _status, 0, opts) do
    get_transaction_receipt(receipt_hash, opts)
  end

  defp wait_on_receipt_status(receipt_hash, status, counter, opts) do
    _ = Logger.info("Waiting on #{receipt_hash} for status #{status} for #{counter} seconds")
    do_wait_on_receipt_status(receipt_hash, status, counter, opts)
  end

  defp do_wait_on_receipt_status(receipt_hash, expected_status, counter, opts) do
    response = get_transaction_receipt(receipt_hash, opts)

    # response might break with {:error, :closed} or {:error, :socket_closed_remotely}

    case response do
      {:ok, nil} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1, opts)

      {:error, :closed} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1, opts)

      {:error, :socket_closed_remotely} ->
        Process.sleep(@sleep_retry_sec)
        do_wait_on_receipt_status(receipt_hash, expected_status, counter - 1, opts)

      {:ok, %{"status" => ^expected_status} = resp} ->
        revert_reason(resp, opts)
        resp

      {:ok, resp} ->
        revert_reason(resp, opts)
        resp
    end
  end

  defp get_transaction_receipt(receipt_hash, opts) do
    Ethereumex.HttpClient.eth_get_transaction_receipt(receipt_hash, opts)
  end

  defp revert_reason(%{"status" => "0x1"}, _), do: :ok

  defp revert_reason(%{"status" => "0x0"} = response, opts) do
    {:ok, tx} = Ethereumex.HttpClient.eth_get_transaction_by_hash(response["transactionHash"], opts)

    {:ok, reason} = Ethereumex.HttpClient.eth_call(Map.put(tx, "data", tx["input"]), tx["blockNumber"], opts)
    hash = response["transactionHash"]

    _ =
      Logger.info(
        "Revert reason for #{inspect(hash)}: revert string: #{inspect(decode_reason(reason))}, revert binary: #{
          inspect(Encoding.to_binary!(reason), limit: :infinity)
        }"
      )
  end

  defp decode_reason(reason) do
    # https://ethereum.stackexchange.com/questions/48383/how-to-receive-revert-reason-for-past-transactions
    reason |> String.split_at(138) |> elem(1) |> Base.decode16!(case: :lower) |> String.chunk(:printable)
  end
end
