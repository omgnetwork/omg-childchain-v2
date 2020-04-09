defmodule Engine.Ethereum.Monitor.Child do
  @moduledoc """
  This implements the restart logic of the Monitor
  """
  require Logger

  @type t :: %__MODULE__{pid: pid(), spec: Supervisor.child_spec()}
  defstruct pid: nil, spec: nil

  @spec start(t() | Supervisor.child_spec()) :: t()
  def start(child) when is_struct(child) do
    case Process.alive?(child.pid) do
      true ->
        child

      false ->
        %{id: _name, start: {child_module, function, args}} = child.spec
        {:ok, pid} = apply(child_module, function, args)
        %__MODULE__{pid: pid, spec: child.spec}
    end
  end

  def start(%{id: _name, start: {child_module, function, args}} = spec) do
    {:ok, pid} = apply(child_module, function, args)
    %__MODULE__{pid: pid, spec: spec}
  end
end
