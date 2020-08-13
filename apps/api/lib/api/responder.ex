defmodule API.Responder do
  @moduledoc """
  Serialize, encode and sends data, either valid or invalid (errors)
  """

  alias Plug.Conn

  @callback respond(Conn.t(), {:ok, map()} | {:error, atom()} | {:error, atom(), String.t()}) :: Conn.t()

  # Sends a response with the encoded data.
  def render_json(conn, data) do
    conn
    |> set_conn_resp_headers()
    |> set_conn_resp(data)
    |> Conn.send_resp()
    |> Conn.halt()
  end

  defp set_conn_resp(conn, data) do
    # Map.get(conn, :status, 200) doesn't work
    status =
      case conn.status do
        nil -> 200
        status -> status
      end

    Conn.resp(conn, status, Jason.encode!(data))
  end

  defp set_conn_resp_headers(conn) do
    Conn.put_resp_content_type(conn, "application/json")
  end
end
