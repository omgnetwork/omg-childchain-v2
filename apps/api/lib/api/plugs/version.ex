defmodule API.Plugs.Version do
  @moduledoc """
  Set the given api_version to the :api_version key of the conn assigns.
  """

  def init(api_version), do: api_version

  def call(conn, api_version), do: Plug.Conn.assign(conn, :api_version, api_version)
end
