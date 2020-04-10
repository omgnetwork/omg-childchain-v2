import Config

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: System.get_env("DATABASE_URL") || "localhost",
  backoff_type: :stop
