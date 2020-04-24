defmodule Status.Alert.AlarmHandler.TableTest do
  use ExUnit.Case, async: true
  alias Status.Alert.AlarmHandler.Table

  setup do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    table_name = String.to_atom("test-#{:rand.uniform(1000)}")
    :ok = Table.table_setup(table_name)
    %{table_name: table_name}
  end

  describe "table_setup/1" do
    test "table setup is ok", %{table_name: table_name} do
      ^table_name = Table.table_name(table_name)
    end
  end

  describe "table_settings/0" do
    test "table name", %{table_name: _table_name} do
      assert [:named_table, :set, :protected, read_concurrency: true] == Table.table_settings()
    end
  end

  describe "write_raise/2" do
    test "we can write to ets and update an alarm", %{table_name: table_name} do
      assert 1 == Table.write_raise(table_name, :yolo)
      assert [yolo: 1] == :ets.tab2list(table_name)
    end
  end

  describe "write_clear/2" do
    test "we can write to ets and update an alarm", %{table_name: table_name} do
      assert 0 == Table.write_clear(table_name, :dyolo)
      assert [dyolo: 0] == :ets.tab2list(table_name)
    end
  end
end
