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
  # alias API.Plugs.ExpectParams.InvalidParams
  alias API.Plugs.Health
  alias API.V1.Controller.Block
  alias API.V1.Controller.Transaction
  alias API.V1.Responder

  @expected_params %{
    "health.check" => [],
    "block.get" => [
      %{name: "hash", type: :hex, required: true}
    ],
    "transaction.submit" => [
      %{name: "transaction", type: :hex, required: true}
    ]
  }

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  plug(ExpectParams, expected_params: @expected_params, responder: Responder)

  plug(:match)
  plug(:dispatch)

  get "health.check" do
    conn
    |> Health.call(%{})
    |> Responder.respond({:ok, %{}})
  end

  post "block.get" do
    data = Block.get_by_hash(conn.params["hash"])
    Responder.respond(conn, data)
  end

  post "transaction.submit" do
    data = Transaction.submit(conn.params["transaction"])
    Responder.respond(conn, data)
  end

  match _ do
    Responder.respond(conn, {:error, :operation_not_found})
  end
end
