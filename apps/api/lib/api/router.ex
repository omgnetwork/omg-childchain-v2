defmodule API.Router do
  @moduledoc """
  The Top-level router. This is where we specify versions and other paths we
  want to forward down to lower level routers.
  """

  use Plug.Router
  use SpandexPhoenix

  alias API.Responder
  alias API.Serializer.Error

  # plug(API.Plugs.Health)
  plug(:match)
  plug(:dispatch)

  forward("/v1", to: API.V1.Router)

  match _ do
    Responder.render_json(conn, Error.serialize(:operation_not_found, "", ""))
  end
end
