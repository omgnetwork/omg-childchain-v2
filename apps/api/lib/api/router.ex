defmodule API.Router do
  @moduledoc """
  The Top-level router. This is where we specify versions and other paths we
  want to forward down to lower level routers.
  """

  use Plug.Router

  plug(Spandex.Plug.StartTrace, tracer: API.Tracer)
  plug(API.Plugs.Health)
  plug(:match)
  plug(:dispatch)
  plug(Spandex.Plug.EndTrace, tracer: API.Tracer)

  forward("/v1", to: API.V1.Router)
end
