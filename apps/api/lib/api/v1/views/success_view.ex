defmodule API.V1.View.Success do
  @moduledoc """
  Contain functions that serialize data into a success v1 format
  """

  alias API.View.Success

  def serialize(data), do: Success.serialize(data, "1.0")
end
