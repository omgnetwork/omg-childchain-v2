defmodule API.Configuration do
  @moduledoc false

  @app :api

  @spec port() :: pos_integer()
  def port() do
    Application.get_env(@app, :port)
  end

  @spec cors_enabled?() :: bool()
  def cors_enabled?() do
    Application.get_env(@app, :cors_enabled)
  end
end
