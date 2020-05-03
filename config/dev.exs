import Config

config :engine,
  url: "http://localhost:8545",
  deposit_finality_margin: 1,
  ethereum_events_check_interval_ms: 800,
  coordinator_eth_height_check_interval_ms: 800
