defmodule API.V1.Serializer.Success do
  @moduledoc """
  """

  alias API.Serializer.Success

  def serialize(data), do: Success.serialize(data, "1.0")
end
