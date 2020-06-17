import Config

config :engine, Engine.Repo,
  database: "engine_repo_test",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost",
  queue_target: 5000,
  queue_interval: 5000,
  pool: Ecto.Adapters.SQL.Sandbox

config :engine, ecto_repos: [Engine.Repo]

config :briefly, directory: ["/tmp/omgisego/childchain"]

config :engine,
  url: "http://localhost:8545",
  deposit_finality_margin: 1,
  ethereum_events_check_interval_ms: 10,
  coordinator_eth_height_check_interval_ms: 10

config :plug, :validate_header_keys_during_test, true
config :logger, level: :warn
