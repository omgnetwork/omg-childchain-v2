defmodule API.Plugs.Health do
  @moduledoc """
  Observes the systems alarms and prevents calls towards an unhealthy one.
  """

  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    if Status.is_healthy() do
      conn
    else
      conn
      |> send_resp(503, "")
      |> halt()
    end
  end
end
