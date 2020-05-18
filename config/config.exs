import Config

parse_contracts = fn ->
  local_umbrella_path = Path.join([File.cwd!(), "../../", "localchain_contract_addresses.env"])

  contract_addreses_path =
    case File.exists?(local_umbrella_path) do
      true ->
        local_umbrella_path

      _ ->
        # CI/CD
        Path.join([File.cwd!(), "localchain_contract_addresses.env"])
    end

  contract_addreses_path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> List.flatten()
  |> Enum.reduce(%{}, fn line, acc ->
    [key, value] = String.split(line, "=")
    Map.put(acc, key, value)
  end)
end

contracts = parse_contracts.()

config :engine,
  finality_margin: 10,
  network: "TEST",
  tx_hash_contract: contracts["TX_HASH_CONTRACT"],
  authority_address: contracts["AUTHORITY_ADDRESS"],
  plasma_framework: contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"],
  erc20_vault: contracts["CONTRACT_ADDRESS_ERC20_VAULT"],
  eth_vault: contracts["CONTRACT_ADDRESS_ETH_VAULT"],
  payment_exit_game: contracts["CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"],
  fee_adapter_check_interval_ms: 10_000

config :engine, Engine.Fees,
  fee_feed_url: "http://localhost:4000/api/v1",
  fee_change_tolerance_percent: 25,
  stored_fee_update_interval_minutes: 1

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost",
  backoff_type: :stop,
  pool_size: 4

config :engine, ecto_repos: [Engine.Repo]

config :ethereumex,
  http_options: [recv_timeout: 20_000]

config :logger, level: :info

config :logger, :console,
  format: "$date $time [$level] $metadata⋅$message⋅\n",
  discard_threshold: 2000,
  metadata: [:module, :function, :request_id, :trace_id, :span_id]

config :logger, Ink,
  name: "childchain",
  exclude_hostname: true

# THIS IS FOR APM - function traces
config :status, Status.Metric.Tracer,
  service: :backend,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :backend,
  env: "local-development-childchain-v2"

config :spandex, :decorators, tracer: Status.Metric.Tracer
config :spandex_phoenix, tracer: Status.Metric.Tracer

config :spandex_ecto, SpandexEcto.EctoLogger, tracer: Status.Metric.Tracer

config :engine, Engine.Repo, telemetry_prefix: [:engine, :repo]

# APMs are sent via HTTP requests
config :spandex_datadog,
  host: "localhost",
  port: 8126,
  batch_size: 10,
  sync_threshold: 100,
  http: HTTPoison

# Metrics are sent via UDP
config :statix,
  host: "localhost",
  port: 8125,
  tags: ["application:childchain-v2", "app_env:local-development"]

config :os_mon,
  disk_almost_full_threshold: 1,
  system_memory_high_watermark: 1

config :engine, Engine.Feefeed.Rules.Scheduler, interval: 180

config :engine, Engine.Feefeed.Rules.Source,
  org: "omisego",
  branch: "master",
  filename: "fee_rules"

config :ex_plasma,
  eip_712_domain: %{
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract: System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK"),
    version: "1"
  }

config :api,
  port: 9656

import_config "#{Mix.env()}.exs"
