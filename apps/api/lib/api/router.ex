defmodule API.Router do
  @moduledoc """
  The Top-level router. This is where we specify versions and other paths we
  want to forward down to lower level routers.
  """

  use Plug.Router
  use SpandexPhoenix

  # plug(API.Plugs.Health)
  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "hello")
  end

  forward("/v1", to: API.V1.Router)
end
