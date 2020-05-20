defmodule API.V1.Router do
  @moduledoc """
  The V1 JSON-RPC API. This should have parity with elixir-omg's API.
  """

  use Plug.Router

  alias API.V1.BlockGet
  alias API.V1.TransactionSubmit

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/block.get" do
    data = BlockGet.by_hash(conn.params)
    render_json(conn, data)
  end

  post "/transaction.submit" do
    data = TransactionSubmit.submit(conn.params)
    render_json(conn, data)
  end

  defp render_json(%{status: status} = conn, data) do
    payload =
      Jason.encode!(%{
        service_name: "childchain",
        version: "1.0",
        data: data
      })

    send_resp(conn, status || 200, payload)
  end
end
