defmodule Engine.MixProject do
  use Mix.Project

  def project do
    [
      app: :engine,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps() ++ plugins()
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :sasl],
      start_phases: [{:boot_done, []}],
      mod: {Engine.Application, []}
    ]
  end

  defp deps do
    [
      {:status, in_umbrella: true},
      {:bus, in_umbrella: true},
      {:ex_abi, "~> 0.5.1"},
      {:ethereumex, "0.6.4"},
      {:ecto_sql, "~> 3.5"},
      {:ex_plasma, git: "https://github.com/omgnetwork/ex_plasma.git", ref: "0336be01bea7b4aeb5b7fbd75edcbe4ad0d1c69f"},
      {:postgrex, "~> 0.15"},
      {:telemetry, "~> 0.4"},
      {:httpoison, "~> 1.7.0"},
      {:decorator, "~> 1.2"},
      {:ex_rlp, "~> 0.5.3"},
      {:spandex_ecto, "~> 0.6.2"},
      {:spandex, "~> 3.0.1"},
      {:spandex_datadog, "~> 1.0.0"},
      # TEST
      {:ex_machina, "~> 2.4", only: [:test]},
      {:briefly, git: "https://github.com/CargoSense/briefly.git", only: [:test]},
      {:fake_server, "~> 2.1", only: :test},
      {:yaml_elixir, "~> 2.4.0", only: [:test]}
    ]
  end

  defp plugins() do
    prod = Mix.env()
    enterprise = System.get_env("ENTERPRISE")

    case {prod, enterprise} do
      {:prod, "0"} ->
        [{:submit_block, git: "git@github.com:omgnetwork/submit_block.git", branch: "master"}]

      {:prod, "1"} ->
        [
          {:gas, git: "git@github.com:omgnetwork/gas.git", branch: "main"},
          {:submit_block, git: "git@github.com:omgnetwork/submit_block_vault.git", branch: "main"}
        ]

      {:prod, _} ->
        exit("You've tried to build a release without any integrations. Export `ENTERPRISE` variable (0 or 1).")

      _ ->
        []
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
