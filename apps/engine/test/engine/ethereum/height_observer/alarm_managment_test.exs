defmodule Engine.Ethereum.HeightObserver.AlarmManagmentTest do
  use ExUnit.Case, async: true
  alias Engine.Ethereum.HeightObserver.AlarmManagement

  test "install and remove an an alarm handler", %{test: test_name} do
    case Application.start(:sasl) do
      {:error, {:already_started, :sasl}} ->
        :ok = Application.stop(:sasl)
        :ok = Application.start(:sasl)

      :ok ->
        :ok
    end

    on_exit(fn ->
      :ok = Application.stop(:sasl)
    end)

    consumer = test_name

    defmodule test_name do
      def init(consumer: consumer) do
        ^consumer = __MODULE__
        {:ok, %{}}
      end
    end

    assert Enum.member?(:gen_event.which_handlers(:alarm_handler), :alarm_handler)
    :ok = AlarmManagement.subscribe_to_alarms(:alarm_handler, test_name, consumer)
    assert Enum.member?(:gen_event.which_handlers(:alarm_handler), test_name)
  end

  test "set connection_alarm when it's not set yet and the response is faulty", %{test: test_name} do
    defmodule test_name do
      def set(alarm) do
        Kernel.send(self(), alarm)
        :ok
      end
    end

    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    defmodule Module.concat(test_name, Types) do
      def ethereum_connection_error(module) do
        {:whoa, module}
      end
    end

    is_alarm_set = false
    height_response = :error
    :ok = AlarmManagement.connection_alarm(test_name, is_alarm_set, height_response)
    assert_receive {:whoa, AlarmManagement}
  end

  test "clears connection_alarm when it's set and the response is a number", %{test: test_name} do
    defmodule test_name do
      def clear(alarm) do
        Kernel.send(self(), alarm)
        :ok
      end
    end

    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    defmodule Module.concat(test_name, Types) do
      def ethereum_connection_error(module) do
        {:whoa, module}
      end
    end

    is_alarm_set = true
    :ok = AlarmManagement.connection_alarm(test_name, is_alarm_set, 1)
    assert_receive {:whoa, AlarmManagement}
  end

  test "that raising is ignored when connection_alarm is raised and the response is still faulty", %{test: test_name} do
    is_alarm_set = true
    height_response = :error
    :ok = AlarmManagement.connection_alarm(test_name, is_alarm_set, height_response)
    refute_receive {:whoa, AlarmManagement}
  end

  test "that we don't raise an alarm when everything is OK", %{test: test_name} do
    is_alarm_set = false
    height = 55
    :ok = AlarmManagement.connection_alarm(test_name, is_alarm_set, height)
    refute_receive {:whoa, AlarmManagement}
  end

  # stall_alarm

  test "set stall_alarm when it's not set yet and the response is faulty", %{test: test_name} do
    defmodule test_name do
      def set(alarm) do
        Kernel.send(self(), alarm)
        :ok
      end
    end

    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    defmodule Module.concat(test_name, Types) do
      def ethereum_stalled_sync(module) do
        {:whoa, module}
      end
    end

    is_alarm_set = false
    is_stalled = true
    :ok = AlarmManagement.stall_alarm(test_name, is_alarm_set, is_stalled)
    assert_receive {:whoa, AlarmManagement}
  end

  test "clears stall_alarm when it's set and the response is a number", %{test: test_name} do
    defmodule test_name do
      def clear(alarm) do
        Kernel.send(self(), alarm)
        :ok
      end
    end

    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    defmodule Module.concat(test_name, Types) do
      def ethereum_stalled_sync(module) do
        {:whoa, module}
      end
    end

    is_alarm_set = true
    is_stalled = false
    :ok = AlarmManagement.stall_alarm(test_name, is_alarm_set, is_stalled)
    assert_receive {:whoa, AlarmManagement}
  end

  test "that raising is ignored when stall_alarm is raised and the response is still faulty", %{test: test_name} do
    is_alarm_set = true
    is_stalled = true
    :ok = AlarmManagement.stall_alarm(test_name, is_alarm_set, is_stalled)
    refute_receive {:whoa, AlarmManagement}
  end

  test "that we don't raise stall_alarm when everything is OK", %{test: test_name} do
    is_alarm_set = false
    is_stalled = false
    :ok = AlarmManagement.stall_alarm(test_name, is_alarm_set, is_stalled)
    refute_receive {:whoa, AlarmManagement}
  end
end
