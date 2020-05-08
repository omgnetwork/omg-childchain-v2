import Config
rpc_url = System.get_env("ETHEREUM_RPC_URL") || "http://localhost:8545"

to_boolean = fn
  "true" -> true
  "false" -> false
  _ -> nil
end

config :engine,
  url: rpc_url,
  network: System.get_env("ETHEREUM_NETWORK"),
  tx_hash_contract: System.get_env("TX_HASH_CONTRACT"),
  authority_address: System.get_env("AUTHORITY_ADDRESS"),
  plasma_framework: System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK"),
  erc20_vault: nil,
  eth_vault: nil,
  payment_exit_game: nil

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: System.get_env("DATABASE_URL") || "localhost",
  backoff_type: :stop

config :ethereumex,
  url: rpc_url,
  http_options: [recv_timeout: 20_000]

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  server_name: System.get_env("HOSTNAME"),
  environment_name: System.get_env("APP_ENV"),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  included_environments: ["development", "production", "staging", "stress", "sandbox"],
  tags: %{
    eth_network: System.get_env("ETHEREUM_NETWORK"),
    app_env: System.get_env("APP_ENV"),
    hostname: System.get_env("HOSTNAME"),
    application: "childchain"
  }

statix_tags = [application: "childchain", app_env: System.get_env("APP_ENV"), hostname: System.get_env("HOSTNAME")]

config :statix,
  host: System.get_env("DD_HOSTNAME") || "datadog",
  port: String.to_integer(System.get_env("DD_PORT") || "8125"),
  tags: Enum.map(statix_tags, fn {key, value} -> "#{key}:#{value}" end)

config :spandex_datadog,
  host: System.get_env("DD_HOSTNAME") || "datadog",
  port: String.to_integer(System.get_env("DD_APM_PORT") || "8126"),
  batch_size: String.to_integer(System.get_env("BATCH_SIZE") || "10"),
  sync_threshold: String.to_integer(System.get_env("SYNC_THRESHOLD") || "100"),
  http: HTTPoison

config :status, Status.Metric.Tracer,
  service: :web,
  adapter: SpandexDatadog.Adapter,
  disabled?: to_boolean.(System.get_env("DD_DISABLED") || "true"),
  type: :web,
  env: System.get_env("APP_ENV") || ""

config :engine, Engine.Feefeed.Rules.Scheduler,
  interval: String.to_integer(System.get_env("RULES_FETCH_INTERVAL") || "180")

config :engine, Engine.Feefeed.Rules.Source,
  token: System.get_env("GITHUB_TOKEN"),
  org: System.get_env("GITHUB_ORGANISATION") || "omisego",
  repo: System.get_env("GITHUB_REPO"),
  branch: System.get_env("GITHUB_BRANCH") || "master",
  filename: System.get_env("GITHUB_FILENAME") || "fee_rules"
