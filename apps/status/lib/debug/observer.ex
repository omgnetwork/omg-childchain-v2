defmodule Status.Debug.Observer do
  @doc """
  https://github.com/zhongwencool/observer_cli
  https://hexdocs.pm/observer_cli/
  """
  def start() do
    :observer_cli.start()
  end
end
