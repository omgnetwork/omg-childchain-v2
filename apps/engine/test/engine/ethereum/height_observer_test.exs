defmodule Engine.Ethereum.HeightObserverTest do
  use ExUnit.Case, async: true
  alias __MODULE__.Alarm
  alias __MODULE__.EthereumClientMock
  alias Engine.Ethereum.HeightObserver
  alias ExPlasma.Encoding

  setup_all do
    _ = Agent.start_link(fn -> %{} end, name: :connector)
    :ok
  end

  setup %{test: test_name} do
    case Application.start(:sasl) do
      {:error, {:already_started, :sasl}} ->
        :ok = Application.stop(:sasl)
        :ok = Application.start(:sasl)

      :ok ->
        :ok
    end

    on_exit(fn ->
      Application.stop(:sasl)
    end)

    check_interval_ms = 8000
    stall_threshold_ms = 16_000
    {:ok, alarm_instance} = Alarm.start_link([])
    :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)

    {:ok, height_observer} =
      HeightObserver.start_link(
        # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
        name: Module.concat(test_name, HeightObserver),
        check_interval_ms: check_interval_ms,
        stall_threshold_ms: stall_threshold_ms,
        eth_module: EthereumClientMock,
        alarm_module: Alarm,
        opts: [url: "not used"]
        # sasl_alarm_handler: HeightObserverTestAlarmHandler
      )

    Agent.update(:connector, fn state -> Map.merge(state, %{height_observer => alarm_instance}) end)

    %{height_observer: height_observer}
  end

  test "height gets updated on init", %{height_observer: height_observer} do
    assert %{ethereum_height: 12} = :sys.get_state(height_observer)

    # handle continue
    assert_receive {:internal_event_bus, :ethereum_new_height, 12}
    # the next time is when the timer kicks in - check_interval_ms which is more then the timeout in refute_receive
    refute_receive {:internal_event_bus, :ethereum_new_height, 13}
  end

  test "timer gets set", %{height_observer: height_observer} do
    assert_receive {:internal_event_bus, :ethereum_new_height, 12}

    refute_receive {:internal_event_bus, :ethereum_new_height, 13}

    assert %{ethereum_height: 12, tref: {_, tref}} = :sys.get_state(height_observer)
    assert is_reference(tref)
  end

  test "handling messages for raising and lowering alarms", %{height_observer: height_observer} do
    GenServer.cast(height_observer, {:set_alarm, :ethereum_connection_error})
    %{connection_alarm_raised: true} = :sys.get_state(height_observer)
    GenServer.cast(height_observer, {:clear_alarm, :ethereum_connection_error})
    %{connection_alarm_raised: false} = :sys.get_state(height_observer)
    GenServer.cast(height_observer, {:set_alarm, :ethereum_stalled_sync})
    %{stall_alarm_raised: true} = :sys.get_state(height_observer)
    GenServer.cast(height_observer, {:clear_alarm, :ethereum_stalled_sync})
    %{stall_alarm_raised: false} = :sys.get_state(height_observer)
  end

  defmodule EthereumClientMock do
    def eth_block_number(_) do
      block_number =
        case Process.get(:eth_block_number) do
          nil ->
            Process.put(:eth_block_number, 12)
            12

          number ->
            Process.put(:eth_block_number, number + 1)
            number + 1
        end

      {:ok, Encoding.to_hex(block_number)}
    end
  end

  defmodule Alarm do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(_) do
      {:ok, %{}}
    end

    def clear_all() do
      GenServer.call(get_instance(), :clear_all)
    end

    def all() do
      GenServer.call(get_instance(), :all)
    end

    def set(alarm) do
      monitor = self()
      GenServer.call(get_instance(), {:set, alarm, monitor})
    end

    def clear(alarm) do
      monitor = self()
      GenServer.call(get_instance(), {:clear, alarm, monitor})
    end

    def handle_call({:set, alarm, monitor}, _, state) do
      GenServer.cast(monitor, {:set_alarm, elem(alarm, 0)})
      {:reply, :ok, Keyword.merge(state, [alarm])}
    end

    def handle_call({:clear, alarm, monitor}, _, state) do
      GenServer.cast(monitor, {:clear_alarm, elem(alarm, 0)})
      {:reply, :ok, Keyword.delete(state, elem(alarm, 0))}
    end

    def handle_call(:all, _, state) do
      {:reply, state, state}
    end

    def handle_call(:clear_all, _, _state) do
      {:reply, :ok, []}
    end

    defp get_instance() do
      height_observer = self()
      %{^height_observer => alarm_instance} = Agent.get(:connector, fn state -> state end)
      alarm_instance
    end

    defmodule Types do
      def ethereum_connection_error(reporter) do
        {:ethereum_connection_error, %{node: Node.self(), reporter: reporter}}
      end

      def ethereum_stalled_sync(reporter) do
        {:ethereum_stalled_sync, %{node: Node.self(), reporter: reporter}}
      end
    end
  end

  defmodule HeightMonitorTestAlarmHandler do
    def start_link() do
      case :gen_event.start_link({:local, __MODULE__}) do
        {:ok, pid} ->
          :gen_event.add_handler(__MODULE__, __MODULE__, [])
          {:ok, pid}

        error ->
          error
      end
    end

    def set_alarm(alarm) do
      :gen_event.notify(__MODULE__, {:set_alarm, alarm})
    end

    def clear_alarm(alarm_id) do
      :gen_event.notify(__MODULE__, {:clear_alarm, alarm_id})
    end

    def get_alarms() do
      :gen_event.call(__MODULE__, __MODULE__, :get_alarms)
    end

    def add_alarm_handler(module) when is_atom(module) do
      :gen_event.add_handler(__MODULE__, module, [])
    end

    def add_alarm_handler(module, args) when is_atom(module) do
      :gen_event.add_handler(__MODULE__, module, args)
    end

    def delete_alarm_handler(module) when is_atom(module) do
      :gen_event.delete_handler(__MODULE__, module, [])
    end

    ## -----------------------------------------------------------------
    ## Default Alarm handler
    # -----------------------------------------------------------------
    def init(_), do: {:ok, []}

    def handle_event({:set_alarm, alarm}, alarms) do
      {:ok, [alarm | alarms]}
    end

    def handle_event({:clear_alarm, alarm_id}, alarms) do
      {:ok, :lists.keydelete(alarm_id, 1, alarms)}
    end

    def handle_event(_, alarms) do
      {:ok, alarms}
    end

    def handle_info(_, alarms), do: {:ok, alarms}

    def handle_call(:get_alarms, alarms), do: {:ok, alarms, alarms}
    def handle_call(_query, alarms), do: {:ok, {:error, :bad_query}, alarms}

    def terminate(:swap, alarms) do
      {:alarm_handler, alarms}
    end

    def terminate(_, _) do
      :ok
    end
  end
end
