defmodule Bus.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    Bus.Supervisor.start_link()
  end
end
