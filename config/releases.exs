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
