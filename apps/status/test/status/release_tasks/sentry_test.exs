defmodule Status.ReleaseTasks.SentryTest do
  use ExUnit.Case, async: true

  alias __MODULE__.SystemMock
  alias Status.ReleaseTasks.Sentry

  test "if environment variables get applied in the configuration", %{test: test_name} do
    expect = [
      sentry: [
        included_environments: ["test"],
        tags: %{
          current_version: "vsn-" <> "#{test_name}"
        }
      ]
    ]

    assert Sentry.load([sentry: [tags: %{}, included_environments: ["test"]]],
             system_adapter: SystemMock,
             current_version: "#{test_name}"
           ) == expect
  end

  defmodule SystemMock do
    def get_env("SENTRY_DSN") do
      "http://sentry.dsn/"
    end

    def get_env("HOSTNAME") do
      "http://127.0.0.1/"
    end

    def get_env("APP_ENV") do
      "test"
    end
  end
end
