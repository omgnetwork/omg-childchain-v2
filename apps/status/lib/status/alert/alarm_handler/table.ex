defmodule Status.Alert.AlarmHandler.Table do
  @moduledoc """
    This is the SASL alarm handler process that gets notified about raised and cleared
    alarms and writes their status in an ETS table (for quick access).
  """

  def setup(table_name) do
    case :ets.info(table_name) do
      :undefined ->
        ^table_name = :ets.new(table_name, table_settings())
        :ok

      _ ->
        :ok
    end
  end

  def table_name(table_name), do: table_name

  def write_raise(table_name, key), do: :ets.update_counter(table_name, key, {2, 1, 1, 1}, {key, 0})

  def write_clear(table_name, key), do: :ets.update_counter(table_name, key, {2, -1, 0, 0}, {key, 1})

  defp table_settings(), do: [:named_table, :set, :protected, read_concurrency: true]
end
