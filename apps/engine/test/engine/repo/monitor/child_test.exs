defmodule Engine.Repo.Monitor.ChildTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias __MODULE__.SimpleProc
  alias Engine.Repo.Monitor.Child

  describe "start where args is child struct" do
    test "if pid is alive, same Child spec is returned" do
      child = %Child{pid: self(), spec: :yolo}
      assert Child.start(child) == child
    end

    test "if pid is not alive, the process is restarted and Child spec is returned with live pid" do
      {:ok, pid} = SimpleProc.start()
      GenServer.stop(pid)
      spec = %{id: :some_id, start: {SimpleProc, :start, []}}
      child = %Child{pid: pid, spec: spec}
      restart = Child.start(child)
      assert Process.alive?(restart.pid)
      assert restart.spec == spec
      GenServer.stop(restart.pid)
    end
  end

  describe "start where args is supervisor struct" do
    test "start the process from supervisor specs and return child spec" do
      spec = %{id: :some_id, start: {SimpleProc, :start, []}}
      child_spec = Child.start(spec)
      assert is_struct(child_spec)
      assert Process.alive?(child_spec.pid)
      assert child_spec.spec == spec
    end
  end

  defmodule SimpleProc do
    def start() do
      GenServer.start(__MODULE__, [])
    end

    def init(_) do
      {:ok, %{}}
    end
  end
end
