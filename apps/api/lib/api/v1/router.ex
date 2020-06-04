defmodule API.V1.Router do
  @moduledoc """
  The V1 JSON-RPC API. This should have parity with elixir-omg's API.
  """

  use Plug.Router
  use Plug.ErrorHandler

  alias API.Plugs.ExpectParams
  alias API.V1.BlockGet
  alias API.V1.TransactionSubmit

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(ExpectParams, key: "hash", path: "/block.get")
  plug(ExpectParams, key: "transaction", path: "/transaction.submit")
  plug(:match)
  plug(:dispatch)

  post "/block.get" do
    data = BlockGet.by_hash(conn.params["hash"])
    render_json(conn, data)
  end

  post "/transaction.submit" do
    data = TransactionSubmit.submit(conn.params)
    render_json(conn, data)
  end

  defp handle_errors(conn, %{reason: error}) do
    render_json(conn, %{
      object: :error,
      code: "operation:missing_params",
      messages: %{
        validation_error: %{
          parameter: error.key
        }
      }
    })
  end

  defp render_json(conn, data) do
    payload =
      Jason.encode!(%{
        service_name: "childchain",
        version: "1.0",
        data: data
      })

    send_resp(conn, conn.status || 200, payload)
  end
end
