defmodule API.Plugs.Health do
  @moduledoc """
  Observes the systems alarms and prevents calls towards an unhealthy one.
  """

  import Plug.Conn

  def init(options), do: options

  def call(conn, _params) do
    if Status.is_healthy() do
      conn
      |> put_status(200)
      |> send_resp(200, "")
    else
      conn
      |> put_status(503)
      |> send_resp(503, "")
    end
  end
end
