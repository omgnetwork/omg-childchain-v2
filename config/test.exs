import Config

config :engine, Engine.Repo,
  database: "engine_repo_test",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost"

config :engine, ecto_repos: [Engine.Repo]

config :os_mon,
  disk_almost_full_threshold: 1,
  system_memory_high_watermark: 1
