defmodule Engine.TestFeeServer do
  @moduledoc """
   FeeServer that used for tests.

  Regular FeeServer returns fees only if it's healthy so
   this module simulates this behaviour.
  """

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: Engine.Fee.Server)
  end

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_call(:healthy?, _from, state) do
    {:reply, true, state}
  end
end
