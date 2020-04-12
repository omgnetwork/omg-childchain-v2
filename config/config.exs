import Config

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost",
  backoff_type: :stop,
  pool_size: 4

config :engine, ecto_repos: [Engine.Repo]

import_config "#{Mix.env()}.exs"
