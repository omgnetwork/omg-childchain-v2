defmodule Status.ReleaseTasks.SetLoggerTest do
  use ExUnit.Case, async: true
  alias Status.ReleaseTasks.SetLogger
  @app :logger

  setup do
    :ok = System.delete_env("LOGGER_BACKEND")

    on_exit(fn ->
      :ok = System.delete_env("LOGGER_BACKEND")
    end)
  end

  test "if environment variables (INK) get applied in the configuration" do
    :ok = System.put_env("LOGGER_BACKEND", "INK")
    config = SetLogger.load([], [])
    backends = config |> Keyword.fetch!(:logger) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, Ink) == true
  end

  test "if environment variables (CONSOLE) get applied in the configuration" do
    # env var to console and asserting that Ink gets removed
    :ok = System.put_env("LOGGER_BACKEND", "conSole")
    config = SetLogger.load([], [])
    backends = config |> Keyword.fetch!(:logger) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, :console) == true
  end

  test "if environment variables are not present the default configuration gets used (INK)" do
    config = SetLogger.load([], [])
    backends = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, :console) == false
    assert Enum.member?(backends, Ink) == true
  end
end
