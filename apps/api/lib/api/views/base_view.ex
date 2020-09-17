defmodule API.View.Base do
  @moduledoc false

  def serialize(data, success, version) do
    %{
      service_name: "child_chain",
      version: version,
      data: data,
      success: success
    }
  end
end
