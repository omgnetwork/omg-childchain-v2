defmodule API.Plugs.Responder do
  @moduledoc """
  Handles sending a response from a conn that has both `:api_version` and `:response` assigns set.
  """

  alias API.ErrorEnhancer
  alias API.View.Error
  alias API.View.Success
  alias Plug.Conn

  def init(options), do: options

  def call(conn, _opts), do: respond(conn, conn.assigns[:response])

  defp respond(conn, nil), do: conn

  defp respond(conn, {:error, _code} = error) do
    respond(conn, ErrorEnhancer.enhance(error))
  end

  defp respond(conn, {:error, code, description}) do
    render_json(conn, Error.serialize(code, description, conn.assigns[:api_version]))
  end

  defp respond(conn, {:ok, data}) do
    render_json(conn, Success.serialize(data, conn.assigns[:api_version]))
  end

  defp render_json(conn, data) do
    conn
    |> set_conn_resp_headers()
    |> set_conn_resp(data)
    |> Conn.send_resp()
    |> Conn.halt()
  end

  defp set_conn_resp_headers(conn) do
    Conn.put_resp_content_type(conn, "application/json")
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
end
