defmodule API.V1.Serializer.Success do
  @moduledoc """
  Contain functions that serialize data into a success v1 format
  """

  alias API.Serializer.Success

  def serialize(data), do: Success.serialize(data, "1.0")
end
