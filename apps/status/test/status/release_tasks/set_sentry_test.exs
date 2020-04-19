defmodule Status.ReleaseTasks.SetSentryTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog, only: [capture_log: 1]

  alias Status.ReleaseTasks.SetSentry

  setup do
    on_exit(fn ->
      :ok = System.delete_env("SENTRY_DSN")
      :ok = System.delete_env("APP_ENV")
      :ok = System.delete_env("HOSTNAME")
      :ok = System.delete_env("ETHEREUM_NETWORK")
      :ok = System.delete_env("ETH_NODE")
    end)

    :ok
  end

  test "if environment variables get applied in the configuration" do
    dsn = "/dsn/dsn/dsn"
    yolo = "YOLO"
    server_name = "server name"
    network = "RINKEBY"
    current_version = "current_version"
    :ok = System.put_env("SENTRY_DSN", dsn)
    :ok = System.put_env("APP_ENV", yolo)
    :ok = System.put_env("HOSTNAME", server_name)
    :ok = System.put_env("ETHEREUM_NETWORK", network)

    capture_log(fn ->
      config = SetSentry.load([], release: :watcher, current_version: current_version)

      config_expect = [
        sentry: [
          dsn: dsn,
          environment_name: yolo,
          included_environments: [yolo],
          server_name: server_name,
          tags: [
            application: :watcher,
            eth_network: network,
            eth_node: :geth,
            current_version: "vsn-" <> current_version,
            app_env: yolo,
            hostname: server_name
          ]
        ]
      ]

      assert config == config_expect
    end)
  end

  test "if sentry is disabled if there's no SENTRY DSN env var set" do
    capture_log(fn ->
      config = SetSentry.load([], release: :child_chain, current_version: "current_version")
      config_expect = [sentry: [included_environments: []]]
      assert config == config_expect
    end)
  end

  test "if faulty eth node exits" do
    :ok = System.put_env("ETH_NODE", "random random random")
    :ok = System.put_env("SENTRY_DSN", "/dsn/dsn/dsn")

    capture_log(fn ->
      assert catch_exit(SetSentry.load([], release: :child_chain, current_version: "current_version"))
    end)
  end
end
