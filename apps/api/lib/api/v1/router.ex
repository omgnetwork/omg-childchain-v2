defmodule API.V1.Router do
  @moduledoc """
  The V1 JSON-RPC API. This should have parity with elixir-omg's API.

  There is a known issue with this v1 API around the transactions returning
  all the data like this. In V2 API, we will address this and quickly move towards that
  to deprecate this API.
  """

  use Plug.Router
  use Plug.ErrorHandler

  alias API.Configuration
  alias API.Plugs.ExpectParams
  alias API.Plugs.Responder
  alias API.Plugs.Version
  alias API.V1.Controller.BlockController
  alias API.V1.Controller.ConfigurationController
  alias API.V1.Controller.FeeController
  alias API.V1.Controller.TransactionController
  alias API.V1.ErrorHandler

  @api_version "1.0"

  @expected_params %{
    "GET:health.check" => [],
    "GET:configuration.get" => [],
    "POST:block.get" => [
      %{name: "hash", type: :hex, required: true}
    ],
    "POST:fees.all" => [
      %{name: "currencies", type: {:list, :hex}, required: false},
      %{name: "tx_types", type: {:list, :non_neg_integer}, required: false}
    ],
    "POST:transaction.submit" => [
      %{name: "transaction", type: :hex, required: true}
    ]
  }

  if Configuration.cors_enabled?(), do: plug(CORSPlug, methods: ["GET", "POST"])
  plug(Version, @api_version)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(ExpectParams, @expected_params)

  # Calling Responder once here to allow early response/halt of conn if there was an error
  # in the pipeline above (ie: missing params). If there is no `:response` key in the conn
  # assigns, this will not do anything.
  plug(Responder)
  plug(:match)
  plug(:dispatch)

  get "health.check" do
    # Health plug will intercept this if alarms were raised
    send_resp(conn, 200, "")
  end

  get "configuration.get" do
    data = ConfigurationController.get()
    put_conn_response(conn, data)
  end

  post "block.get" do
    data = BlockController.get_by_hash(conn.params["hash"])
    put_conn_response(conn, data)
  end

  post "transaction.submit" do
    data = TransactionController.submit(conn.params["transaction"])
    put_conn_response(conn, data)
  end

  post "fees.all" do
    data = FeeController.all(conn.params)
    put_conn_response(conn, data)
  end

  match _ do
    put_conn_response(conn, {:error, :operation_not_found})
  end

  # Calling Reponder as the last step of the pipeline. At this point, the conn is expected
  # to have :response and :api_version keys in its assigns.
  plug(Responder)

  # Errors raised by Plugs
  defp handle_errors(conn, error), do: ErrorHandler.handle(conn, error)

  defp put_conn_response(conn, data), do: assign(conn, :response, data)
end
