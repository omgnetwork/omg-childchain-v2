defmodule API.V1.Serializer.Error do
  @moduledoc """
  Contain functions that serialize errors into a v1 format
  """

  alias API.Serializer.Error

  def serialize({:error, code, description}), do: serialize(code, description)
  def serialize(code, description), do: Error.serialize(code, description, "1.0")
end
