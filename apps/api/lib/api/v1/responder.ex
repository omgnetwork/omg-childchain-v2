defmodule API.V1.Responder do
  @moduledoc """
  Serialize, encode and sends data, either valid or invalid (errors)
  """

  alias API.V1.ErrorEnhancer
  alias API.V1.Serializer.Error
  alias API.V1.Serializer.Success
  alias Plug.Conn

  def respond(conn, {:error, _code} = error) do
    respond(conn, ErrorEnhancer.enhance(error))
  end

  def respond(conn, {:error, _code, _description} = error) do
    render_json(conn, Error.serialize(error))
  end

  def respond(conn, {:ok, data}) do
    render_json(conn, Success.serialize(data))
  end

  # Sends a V1 response with the encoded data.
  defp render_json(conn, data) do
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
