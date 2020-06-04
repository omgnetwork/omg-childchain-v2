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
  finality_margin: 1,
  ethereum_events_check_interval_ms: 10,
  coordinator_eth_height_check_interval_ms: 10

config :ex_plasma,
  eip_712_domain: %{
    name: "OMG Network",
    salt: "0xfad5c7f626d80f9256ef01929f3beb96e058b8b4b0e3fe52d84f054c0e2a7a83",
    verifying_contract:
      System.get_env("CONTRACT_ADDRESS_PLASMA_FRAMEWORK", "0xd17e1233a03affb9092d5109179b43d6a8828607"),
    version: "1"
  }

config :plug, :validate_header_keys_during_test, true
config :logger, level: :warn
  ethereum_events_check_interval_ms: 10
