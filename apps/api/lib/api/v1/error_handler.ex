defmodule API.V1.ErrorHandler do
  @moduledoc """
  Handle errors raised by plugs and format them before responding
  """

  alias API.Plugs.Responder
  alias Plug.Conn
  alias Plug.Parsers

  def handle(conn, %{reason: %Parsers.RequestTooLargeError{}}) do
    respond(conn, {:error, :request_too_large})
  end

  def handle(conn, %{reason: %Parsers.UnsupportedMediaTypeError{}}) do
    respond(conn, {:error, :unsupported_media_type_error})
  end

  def handle(conn, %{reason: %Parsers.ParseError{}}) do
    respond(conn, {:error, :malformed_body})
  end

  def handle(conn, _error) do
    respond(conn, {:error, :unexpected_error})
  end

  defp respond(conn, error) do
    conn
    |> Conn.put_status(400)
    |> Conn.assign(:response, error)
    |> Responder.call([])
  end
end
