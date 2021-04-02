import Config

config :engine, Engine.Repo,
  database: "engine_repo_test",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost",
  ownership_timeout: 400_000,
  pool_size: 10,
  queue_target: 100,
  queue_interval: 5000,
  pool: Ecto.Adapters.SQL.Sandbox,
  log_level: :warn

config :engine, ecto_repos: [Engine.Repo]

config :briefly, directory: ["/tmp/omisego/childchain"]

config :engine,
  url: "http://localhost:8545",
  finality_margin: 1,
  ethereum_events_check_interval_ms: 10,
  coordinator_eth_height_check_interval_ms: 500,
  prepare_block_for_submission_interval_ms: 500

config :ex_plasma,
  eip_712_domain: %{
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract:
      System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", "0xd17e1233a03affb9092d5109179b43d6a8828607"),
    version: "2"
  }

config :plug, :validate_header_keys_during_test, true
config :logger, level: :warn
