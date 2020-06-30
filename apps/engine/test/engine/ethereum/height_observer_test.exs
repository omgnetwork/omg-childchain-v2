defmodule Engine.Ethereum.HeightObserverTest do
  use ExUnit.Case, async: true
  alias __MODULE__.Alarm
  alias __MODULE__.EthereumClientMock
  alias __MODULE__.EventBusListener
  alias __MODULE__.HeightObserverTestAlarmHandler
  alias Engine.Ethereum.HeightObserver
  alias Engine.Ethereum.HeightObserver.AlarmManagement
  alias ExPlasma.Encoding

  setup_all do
    HeightObserverTestAlarmHandler.start_link()
    {:ok, _} = EthereumClientMock.start_link()
    _ = Agent.start_link(fn -> %{} end, name: :connector)
    :ok
  end

  setup %{test: test_name} do
    check_interval_ms = 10
    stall_threshold_ms = 100
    {:ok, alarm_instance} = Alarm.start_link([])

    {:ok, monitor} =
      HeightObserver.start_link(
        # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
        name: Module.concat(test_name, HeightObserver),
        check_interval_ms: check_interval_ms,
        stall_threshold_ms: stall_threshold_ms,
        eth_module: EthereumClientMock,
        alarm_module: Alarm,
        opts: [url: "not used"],
        sasl_alarm_handler: HeightObserverTestAlarmHandler
      )

    test_pid = self()
    Agent.update(:connector, fn state -> Map.merge(state, %{monitor => alarm_instance, test_pid => alarm_instance}) end)

    _ =
      on_exit(fn ->
        _ = EthereumClientMock.reset_state()
        _ = Process.sleep(10)
        true = Process.exit(monitor, :kill)
      end)

    {:ok,
     %{
       monitor: monitor,
       check_interval_ms: check_interval_ms,
       stall_threshold_ms: stall_threshold_ms
     }}
  end

  #
  # Internal event publishing
  #

  test "that an ethereum_new_height event is published when the height increases", context do
    _ = EthereumClientMock.set_stalled(false)

    {:ok, listener} = EventBusListener.start(self())
    on_exit(fn -> GenServer.stop(listener) end)

    assert_receive(:got_ethereum_new_height, Kernel.trunc(context.check_interval_ms * 10))
  end

  #
  # Connection error
  #
  # alarm managment test
  # test "that the connection alarm gets raised when connection becomes unhealthy" do
  #   # Initialize as healthy and alarm not present
  #   _ = EthereumClientMock.set_faulty_response(false)

  #   # Toggle faulty response
  #   spawn(fn ->
  #     Process.sleep(70)
  #     _ = EthereumClientMock.set_faulty_response(true)
  #   end)

  #   # Assert the alarm and event are present
  #   assert pull_client_alarm(
  #            [ethereum_connection_error: %{node: :nonode@nohost, reporter: AlarmManagement}],
  #            100
  #          ) == :ok
  # end
  # alarm managment test
  # test "that the connection alarm gets cleared when connection becomes healthy" do
  #   # Initialize as unhealthy
  #   _ = EthereumClientMock.set_faulty_response(true)

  #   :ok =
  #     pull_client_alarm(
  #       [ethereum_connection_error: %{node: :nonode@nohost, reporter: AlarmManagement}],
  #       100
  #     )

  #   # Toggle healthy response
  #   _ = EthereumClientMock.set_faulty_response(false)

  #   # Assert the alarm and event are no longer present
  #   assert pull_client_alarm([], 100) == :ok
  # end

  #
  # Stalling sync
  #
  # alarm managment test
  # test "that the stall alarm gets raised when block height stalls" do
  #   # Initialize as healthy and alarm not present
  #   _ = EthereumClientMock.set_stalled(false)
  #   :ok = pull_client_alarm([], 200)

  #   # Toggle stalled height
  #   _ = EthereumClientMock.set_stalled(true)

  #   # Assert alarm now present
  #   assert pull_client_alarm(
  #            [ethereum_stalled_sync: %{node: :nonode@nohost, reporter: AlarmManagement}],
  #            200
  #          ) == :ok
  # end
  # alarm managment test
  # test "that the stall alarm gets cleared when block height unstalls" do
  #   # Initialize as unhealthy
  #   _ = EthereumClientMock.set_stalled(true)

  #   :ok = pull_client_alarm([ethereum_stalled_sync: %{node: :nonode@nohost, reporter: AlarmManagement}], 300)

  #   # Toggle unstalled height
  #   _ = EthereumClientMock.set_stalled(false)

  #   # Assert alarm no longer present
  #   assert pull_client_alarm([], 300) == :ok
  # end

  defp pull_client_alarm(_, 0), do: {:cant_match, Alarm.all()}

  defp pull_client_alarm(match, n) do
    case Alarm.all() do
      ^match ->
        :ok

      _ ->
        Process.sleep(50)
        pull_client_alarm(match, n - 1)
    end
  end

  #
  # Test submodules
  #

  defmodule EthereumClientMock do
    @moduledoc """
    Mocking the ETH module integration point.
    """
    use GenServer

    @initial_state %{height: "0x0", faulty: false, stalled: false}

    def start_link(), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

    def eth_block_number(_), do: GenServer.call(__MODULE__, :eth_block_number)

    def set_faulty_response(faulty), do: GenServer.call(__MODULE__, {:set_faulty_response, faulty})

    def set_long_response(milliseconds), do: GenServer.call(__MODULE__, {:set_long_response, milliseconds})

    def set_stalled(stalled), do: GenServer.call(__MODULE__, {:set_stalled, stalled})

    def reset_state(), do: GenServer.call(__MODULE__, :reset_state)

    def stop(), do: GenServer.stop(__MODULE__, :normal)

    def init(_), do: {:ok, @initial_state}

    def handle_call(:reset_state, _, _state), do: {:reply, :ok, @initial_state}

    def handle_call({:set_faulty_response, true}, _, state), do: {:reply, :ok, %{state | faulty: true}}
    def handle_call({:set_faulty_response, false}, _, state), do: {:reply, :ok, %{state | faulty: false}}

    def handle_call({:set_long_response, milliseconds}, _, state) do
      {:reply, :ok, Map.merge(%{long_response: milliseconds}, state)}
    end

    def handle_call({:set_stalled, true}, _, state), do: {:reply, :ok, %{state | stalled: true}}
    def handle_call({:set_stalled, false}, _, state), do: {:reply, :ok, %{state | stalled: false}}

    # Heights management

    def handle_call(:eth_block_number, _, %{faulty: true} = state) do
      {:reply, :error, state}
    end

    def handle_call(:eth_block_number, _, %{long_response: milliseconds} = state) when is_number(milliseconds) do
      _ = Process.sleep(milliseconds)
      {:reply, {:ok, state.height}, %{state | height: next_height(state.height, state.stalled)}}
    end

    def handle_call(:eth_block_number, _, state) do
      {:reply, {:ok, state.height}, %{state | height: next_height(state.height, state.stalled)}}
    end

    defp next_height(height, false), do: Encoding.to_hex(Encoding.to_int(height) + 1)
    defp next_height(height, true), do: height
  end

  defmodule EventBusListener do
    use GenServer

    def start(parent), do: GenServer.start(__MODULE__, parent)

    def init(parent) do
      :ok = Bus.subscribe({:root_chain, "ethereum_new_height"}, link: true)
      {:ok, parent}
    end

    def handle_info({:internal_event_bus, :ethereum_new_height, _height}, parent) do
      _ = send(parent, :got_ethereum_new_height)
      {:noreply, parent}
    end
  end

  defmodule Alarm do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args)
    end

    def init(_) do
      {:ok, []}
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
      monitor = self()
      %{^monitor => alarm_instance} = Agent.get(:connector, fn state -> state end)
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