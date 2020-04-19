defmodule Status.Metric.DatadogTest do
  use ExUnit.Case, async: true
  alias Status.Metric.Datadog

  test "if exiting process/port sends an exit signal to the parent process" do
    parent = self()

    {:ok, _} =
      Task.start(fn ->
        {:ok, datadog_pid} = Datadog.start_link()
        port = Port.open({:spawn, "cat"}, [:binary])
        true = Process.link(datadog_pid)
        send(parent, {:data, port, datadog_pid})

        # we want to exit because the port forcefully closes
        # so this sleep shouldn't happen
        Process.sleep(10_000)
      end)

    receive do
      {:data, port, datadog_pid} ->
        :erlang.trace(datadog_pid, true, [:receive])
        true = Process.exit(port, :portkill)
        assert_receive {:trace, ^datadog_pid, :receive, {:EXIT, port, :portkill}}
    end
  end
end
