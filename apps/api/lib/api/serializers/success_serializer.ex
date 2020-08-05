defmodule API.Serializer.Success do
  @moduledoc """
  Contain functions that serialize data into a success format
  """

  alias API.Serializer.Base

  def serialize(data, version), do: Base.serialize(data, true, version)
end
