defmodule RPC.Router do
  @moduledoc """
  JSON-RPC API for the Childchain.
  """

  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason

  post "/block.get" do
  end

  post "/transaction.submit" do
  end

  get "/alarm.get" do
  end

  get "/configuration.get" do
  end

  post "/fees.all" do
  end

  match _, do: send_resp(conn, 404, "not found")
end
