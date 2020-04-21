import Config

config :engine,
  network: System.get_env("ETHEREUM_NETWORK"),
  txhash_contract: System.get_env("TXHASH_CONTRACT"),
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
  url: System.get_env("ETHEREUM_RPC_URL"),
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
