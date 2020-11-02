import Config

config :engine,
  url: "http://localhost:8555",
  finality_margin: 1,
  ethereum_events_check_interval_ms: 800

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost"
