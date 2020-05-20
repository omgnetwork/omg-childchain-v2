defmodule Engine.Ethereum.HeightTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.Height

  setup_all do
    {:ok, apps} = Application.ensure_all_started(:bus)
    start_supervised({Height, []})

    on_exit(fn ->
      apps |> Enum.reverse() |> Enum.each(&Application.stop/1)
    end)

    :ok
  end

  test "starting state is initialized with an error tuple" do
    {:ok, {:error, :ethereum_height}} = Height.init(event_bus: Bus)
  end

  test "a call returns a number tuple" do
    {:reply, {:ok, 1}, 1} = Height.handle_call(:get, self(), 1)
  end

  test "a call returns a error tuple" do
    {:reply, {:error, :ethereum_height}, {:error, :ethereum_height}} =
      Height.handle_call(:get, self(), {:error, :ethereum_height})
  end

  describe "statefull test" do
    test "that the process stores the height when it recieves it" do
      pid = Process.whereis(Height)
      assert Height.get() == {:error, :ethereum_height}
      :erlang.trace(pid, true, [:receive])
      event = Bus.Event.new({:root_chain, "ethereum_new_height"}, :ethereum_new_height, 1)
      Bus.local_broadcast(event)
      assert_receive {:trace, ^pid, :receive, {:internal_event_bus, :ethereum_new_height, 1}}
      assert Height.get() == {:ok, 1}
    end
  end
end
