defmodule RPC.Router do
  @moduledoc """
  JSON-RPC API for the Childchain.
  """

  use Plug.Router

  alias Engine.DB.Block
  alias Engine.Repo
  alias ExPlasma.Encoding

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/block.get" do
    case Map.get(conn.params, "hash") do
      nil ->
        send_error(conn, 400)
      hash ->

        block = hash |> Encoding.to_binary() |> Block.get_by_hash() |> Repo.preload(:transactions)

        case block do
          nil ->
            send_payload(conn, 204, %{})
          block ->
            send_payload(conn, 200, %{
              blknum: block.number,
              hash: Encoding.to_hex(block.hash),
              transactions: Enum.map(block.transactions, fn txn -> Encoding.to_hex(txn.tx_bytes) end)
            })
        end
    end
  end

  # post "/transaction.submit" do
  # end

  # get "/alarm.get" do
  # end

  # get "/configuration.get" do
  # end

  # post "/fees.all" do
  # end

  # match _, do: send_resp(conn, 404, "not found")

  defp send_payload(conn, http_code, data) do
    payload =
      Jason.encode!(%{
        service_name: "childchain",
        version: "1.0",
        data: data
      })

    send_resp(conn, http_code, payload)
  end

  defp send_error(conn, http_code) do
    payload = %{
      object: "error",
      code: "",
      description: "",
      messages: %{error_key: "not_found"}
    }

    send_payload(conn, http_code, payload)
  end
end
