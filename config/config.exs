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
  txhash_contract: contracts["TXHASH_CONTRACT"],
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

import_config "#{Mix.env()}.exs"
