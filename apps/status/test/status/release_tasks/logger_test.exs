defmodule Status.ReleaseTasks.LoggerTest do
  use ExUnit.Case, async: true

  alias Status.ReleaseTasks.Logger
  @app :logger

  test "if environment variables (INK) get applied in the configuration", %{test: test_name} do
    defmodule test_name do
      def get_env("LOGGER_BACKEND") do
        "INK"
      end
    end

    config = Logger.load([], sentry_logger: Sentry.LoggerBackend, default_logger: Ink, system_adapter: test_name)
    backends = config |> Keyword.fetch!(:logger) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, Ink) == true
  end

  test "if environment variables (CONSOLE) get applied in the configuration", %{test: test_name} do
    # env var to console and asserting that Ink gets removed
    defmodule test_name do
      def get_env("LOGGER_BACKEND") do
        "conSole"
      end
    end

    :ok = System.put_env("LOGGER_BACKEND", "conSole")
    config = Logger.load([], sentry_logger: Sentry.LoggerBackend, default_logger: Ink, system_adapter: test_name)
    backends = config |> Keyword.fetch!(:logger) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, :console) == true
  end

  test "if environment variables are not present the default configuration gets used (INK)", %{test: test_name} do
    defmodule test_name do
      def get_env("LOGGER_BACKEND") do
        nil
      end
    end

    config = Logger.load([], sentry_logger: Sentry.LoggerBackend, default_logger: Ink, system_adapter: test_name)
    backends = config |> Keyword.fetch!(@app) |> Keyword.fetch!(:backends)
    assert Enum.member?(backends, :console) == false
    assert Enum.member?(backends, Ink) == true
  end
end
