defmodule Status.Alert.AlarmPrinterTest do
  use ExUnit.Case, async: true

  alias Status.AlarmPrinter

  setup do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    args = [alarm_module: __MODULE__.Alarm, name: String.to_atom("test-#{:rand.uniform(1000)}")]
    {:ok, alarm_printer} = AlarmPrinter.start_link(args)

    %{alarm_printer: alarm_printer}
  end

  test "if the process has a previous backoff set", %{alarm_printer: alarm_printer} do
    :erlang.trace(alarm_printer, true, [:receive])
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    assert is_number(previous_backoff)
  end

  # slow af
  @tag :skip
  test "that the process sends itself a message after startup", %{alarm_printer: alarm_printer} do
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    :erlang.trace(alarm_printer, true, [:send])
    :ok = Process.sleep(previous_backoff)

    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 1", {_, _}, _}}}, Logger}

    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 2", {_, _}, _}}}, Logger}

    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 3", {_, _}, _}}}, Logger}
  end

  # slow af
  @tag :skip
  test "that the process increases the backoff", %{alarm_printer: alarm_printer} do
    %{previous_backoff: previous_backoff} = :sys.get_state(alarm_printer)
    :erlang.trace(alarm_printer, true, [:send])
    :ok = Process.sleep(previous_backoff)

    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 1", {_, _}, _}}}, Logger}

    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 2", {_, _}, _}}}, Logger}

    assert_receive {:trace, _, :send, {:notify, {:warn, _, {Logger, "An alarm was raised 3", {_, _}, _}}}, Logger}

    %{previous_backoff: previous_backoff_1} = :sys.get_state(alarm_printer)
    assert previous_backoff_1 > previous_backoff
  end

  defmodule Alarm do
    def all(), do: [1, 2, 3]
  end
end
