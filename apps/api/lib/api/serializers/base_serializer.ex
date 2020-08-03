defmodule API.Serializer.Base do
  @moduledoc """
  """

  def serialize(data, success, version) do
    %{
      service_name: "childchain",
      version: version,
      data: data,
      success: success
    }
  end
end
