defmodule RPC.Router do
  @moduledoc """
  JSON-RPC API for the Childchain.
  """

  use Plug.Router

  alias RPC.Router.Block
  alias RPC.Router.Transaction

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(:dispatch)

  post "/block.get" do
    data = Block.get_by_hash(conn.params)
    render_json(conn, data)
  end

  post "/transaction.submit" do
    data = Transaction.submit(conn.params)
    render_json(conn, data)
  end

  # match _, do: send_resp(conn, 404, "not found")

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
