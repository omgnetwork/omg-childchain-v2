import Config

config :engine, Engine.Repo,
  database: "engine_repo_test",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost"

config :engine, ecto_repos: [Engine.Repo]
config :logger, level: :info
