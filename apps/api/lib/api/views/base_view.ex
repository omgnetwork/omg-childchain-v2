defmodule API.View.Base do
  @moduledoc false

  def serialize(data, success, version) do
    %{
      service_name: "childchain",
      version: version,
      data: data,
      success: success
    }
  end
end
