defmodule API.V1.Responder do
  @moduledoc """
  Serialize, encode and sends data, either valid or invalid (errors)
  """

  @behaviour API.Responder

  alias API.Responder, as: BaseResponder
  alias API.V1.ErrorEnhancer
  alias API.V1.Serializer.Error
  alias API.V1.Serializer.Success

  @impl BaseResponder
  def respond(conn, {:error, _code} = error) do
    respond(conn, ErrorEnhancer.enhance(error))
  end

  def respond(conn, {:error, _code, _description} = error) do
    BaseResponder.render_json(conn, Error.serialize(error))
  end

  def respond(conn, {:ok, data}) do
    BaseResponder.render_json(conn, Success.serialize(data))
  end
end
