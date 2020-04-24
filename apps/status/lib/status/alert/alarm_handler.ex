defmodule Status.Alert.AlarmHandler do
  @moduledoc """
    This is the SASL alarm handler process that gets notified about raised and cleared
    alarms and writes their status in an ETS table (for quick access).
  """
  alias Status.Alert.AlarmHandler.Table
  @table_name :alarms

  @doc """
  This is called only once on startup!
  """
  def install(alarm_types, table_name \\ @table_name) do
    case Enum.member?(:gen_event.which_handlers(:alarm_handler), __MODULE__) do
      true -> :ok
      _ -> :alarm_handler.add_alarm_handler(__MODULE__, alarm_types: alarm_types, table_name: table_name)
    end
  end

  def select(match) do
    :ets.select(@table_name, match)
  end

  def table_name(), do: Table.table_name(@table_name)

  @type t :: %__MODULE__{alarms: list(), table_name: atom()}
  defstruct [:alarms, :table_name]
  # -----------------------------------------------------------------
  # :gen_event handlers
  # -----------------------------------------------------------------
  def init(args) do
    table_name = Keyword.fetch!(args, :table_name)
    alarm_types = Keyword.fetch!(args, :alarm_types)
    :ok = Table.table_setup(table_name)
    :ok = Enum.each(alarm_types, &Table.write_clear(table_name, &1))
    {:ok, %__MODULE__{table_name: table_name, alarms: []}}
  end

  def handle_call(:get_alarms, state) do
    {:ok, state.alarms, state}
  end

  def handle_event({:set_alarm, new_alarm}, state) do
    # was the alarm raised already and is this our type of alarm?

    case Enum.any?(state.alarms, &(&1 == new_alarm)) do
      true ->
        {:ok, state}

      false ->
        # the alarm has not been raised before and we're subscribed
        _ = Table.write_raise(state.table_name, elem(new_alarm, 0))
        {:ok, %{state | alarms: [new_alarm | state.alarms]}}
    end
  end

  def handle_event({:clear_alarm, alarm_id}, state) do
    new_alarms =
      state.alarms
      |> Enum.filter(&(elem(&1, 0) != alarm_id))
      |> Enum.filter(&(&1 != alarm_id))

    _ = Table.write_clear(state.table_name, alarm_id)
    {:ok, %{state | alarms: new_alarms}}
  end
end
