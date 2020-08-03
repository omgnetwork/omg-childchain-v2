defmodule API.Serializer.Success do
  @moduledoc """
  """

  alias API.Serializer.Base

  def serialize(data, version), do: Base.serialize(data, true, version)
end
