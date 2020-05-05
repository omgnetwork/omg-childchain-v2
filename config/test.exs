import Config

config :engine, Engine.Repo,
  database: "engine_repo_test",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :engine, ecto_repos: [Engine.Repo]

config :briefly, directory: ["/tmp/omgisego/childchain"]

config :engine,
  url: "http://localhost:8545",
  deposit_finality_margin: 1,
  ethereum_events_check_interval_ms: 10,
  coordinator_eth_height_check_interval_ms: 10

config :engine,
  block_queue_eth_height_check_interval_ms: 100,
  fee_adapter_check_interval_ms: 1_000,
  fee_buffer_duration_ms: 5_000,
  fee_adapter:
    {Engine.Fees.Adapters.File,
     opts: [specs_file_path: Path.join(__DIR__, "../apps/engine/test/engine/support/fee_specs.json")]}
