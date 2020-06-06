import Config

parse_contracts = fn ->
  local_umbrella_path = Path.join([File.cwd!(), "../../", "localchain_contract_addresses.env"])

  contract_addreses_path =
    case File.exists?(local_umbrella_path) do
      true ->
        local_umbrella_path

      _ ->
        # CI/CD
        Path.join([File.cwd!(), "localchain_contract_addresses.env"])
    end

  contract_addreses_path
  |> File.read!()
  |> String.split("\n", trim: true)
  |> List.flatten()
  |> Enum.reduce(%{}, fn line, acc ->
    [key, value] = String.split(line, "=")
    Map.put(acc, key, value)
  end)
end

contracts = parse_contracts.()

config :engine,
  network: "TEST",
  tx_hash_contract: contracts["TX_HASH_CONTRACT"],
  authority_address: contracts["AUTHORITY_ADDRESS"],
  plasma_framework: contracts["CONTRACT_ADDRESS_PLASMA_FRAMEWORK"],
  erc20_vault: contracts["CONTRACT_ADDRESS_ERC20_VAULT"],
  eth_vault: contracts["CONTRACT_ADDRESS_ETH_VAULT"],
  payment_exit_game: contracts["CONTRACT_ADDRESS_PAYMENT_EXIT_GAME"]

config :engine, Engine.Repo,
  database: "engine_repo",
  username: "omisego_dev",
  password: "omisego_dev",
  hostname: "localhost",
  backoff_type: :stop,
  pool_size: 4

config :engine, ecto_repos: [Engine.Repo]

config :ethereumex,
  http_options: [recv_timeout: 20_000]

config :logger, level: :info

config :logger, :console,
  format: "$date $time [$level] $metadata⋅$message⋅\n",
  discard_threshold: 2000,
  metadata: [:module, :function, :request_id, :trace_id, :span_id]

config :logger, Ink,
  name: "childchain",
  exclude_hostname: true

config :status, Status.Metric.Tracer,
  service: :web,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :web,
  env: ""

config :spandex_datadog,
  host: "datadog",
  port: 8126,
  batch_size: 10,
  sync_threshold: 100,
  http: HTTPoison

config :os_mon,
  disk_almost_full_threshold: 1,
  system_memory_high_watermark: 1

config :engine, Engine.Feefeed.Rules.Scheduler, interval: 180

config :engine, Engine.Feefeed.Rules.Worker.Source,
  org: "omgnetwork",
  repo: "fee-rules",
  branch: "master",
  filename: "fee_rules"

import_config "#{Mix.env()}.exs"
