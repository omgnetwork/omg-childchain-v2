defmodule API.View.Error do
  @moduledoc """
  Contain functions that serialize errors
  """

  alias API.View.Base

  def serialize(code, description, version) do
    data = %{
      code: code,
      description: description,
      object: "error"
    }

    Base.serialize(data, false, version)
  end
end
