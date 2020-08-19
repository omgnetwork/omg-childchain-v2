defmodule API.View.Success do
  @moduledoc """
  Contain functions that serialize data into a success format
  """

  alias API.View.Base

  def serialize(data, version), do: Base.serialize(data, true, version)
end
