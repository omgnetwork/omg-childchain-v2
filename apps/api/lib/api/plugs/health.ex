defmodule API.Plugs.Health do
  @moduledoc """
  Observes the systems alarms and prevents calls towards an unhealthy one.
  """

  import Plug.Conn

  def init(options), do: options

  def call(conn, _params) do
    if Status.is_healthy() do
      send_resp(conn, 200, "")
    else
      send_resp(conn, 503, "")
    end
  end
end
