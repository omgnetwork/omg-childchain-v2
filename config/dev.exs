import Config

config :engine,
  rpc_url: "http://localhost:8555",
  finality_margin: 1,
  ethereum_events_check_interval_ms: 800

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost"

config :engine, Engine.Fee,
  fee_feed_url: System.get_env("FEE_FEED_URL", "http://localhost:4000/api/v1"),
  fee_change_tolerance_percent: String.to_integer(System.get_env("FEE_CHANGE_TOLERANCE_PERCENT") || "25"),
  stored_fee_update_interval_minutes: String.to_integer(System.get_env("STORED_FEE_UPDATE_INTERVAL_MINUTES") || "1")
