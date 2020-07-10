defmodule Status.Debug.Observer do
  @moduledoc """
  https://github.com/zhongwencool/observer_cli
  https://hexdocs.pm/observer_cli/
  """
  @spec start() :: no_return()
  def start() do
    :observer_cli.start()
  end
end
