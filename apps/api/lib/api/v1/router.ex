defmodule API.V1.Router do
  @moduledoc """
  The V1 JSON-RPC API. This should have parity with elixir-omg's API.

  There is a known issue with this v1 API around the transactions returning
  all the data like this. In V2 API, we will address this and quickly move towards that
  to deprecate this API.
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

  get "/foo" do
    render_json(conn, 200, %{})
  end

  post "/block.get" do
    data = BlockGet.by_hash(conn.params["hash"])
    render_json(conn, 200, data)
  end

  post "/transaction.submit" do
    data = TransactionSubmit.submit(conn.params["transaction"])
    render_json(conn, 200, data)
  end

  # The "input validations" are being raised up through the plug pipeline's as errors. We
  # catch ArgumentError here as we are using this with ExpectParams to raise the error message here.
  defp handle_errors(conn, %{reason: %ArgumentError{message: message}}) do
    render_json(conn, 400, %{error: message})
  end

  # V1 Parity wraps the body of the contents with this.
  defp render_json(conn, status, data) do
    payload =
      Jason.encode!(%{
        service_name: "childchain",
        version: "1.0",
        data: data
      })

    send_resp(conn, status, payload)
  end
end
