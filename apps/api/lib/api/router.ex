defmodule API.Router do
  @moduledoc """
  The Top-level router. This is where we specify versions and other paths we
  want to forward down to lower level routers.
  """

  use Plug.Router
  use SpandexPhoenix

  alias API.Plugs.Responder

  # plug(API.Plugs.Health)
  plug(:match)
  plug(:dispatch)

  forward("/v1", to: API.V1.Router)

  match _ do
    conn
    |> assign(:api_version, "-")
    |> assign(:response, {:error, :operation_not_found})
  end

  plug(Responder)
end
