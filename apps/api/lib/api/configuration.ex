defmodule API.Configuration do
  @moduledoc false

  @spec port() :: pos_integer()
  def port() do
    Application.get_env(:api, :port)
  end
end
