defmodule Engine.Ethereum.Monitor.Start do
  @moduledoc """
  This implements the restart logic of the Monitor
  """
  require Logger

  alias Engine.Ethereum.Monitor.Child

  @spec start_child(Child.t() | Supervisor.child_spec()) :: Child.t()
  def start_child(child) when is_struct(child) do
    case Process.alive?(child.pid) do
      true ->
        child

      false ->
        %{id: _name, start: {child_module, function, args}} = child.spec
        {:ok, pid} = apply(child_module, function, args)
        %Child{pid: pid, spec: child.spec}
    end
  end

  def start_child(%{id: _name, start: {child_module, function, args}} = spec) do
    {:ok, pid} = apply(child_module, function, args)
    %Child{pid: pid, spec: spec}
  end
end
