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
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [
      extra_applications: [:logger, :sasl],
      start_phases: [{:boot_done, []}],
      mod: {Engine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:status, in_umbrella: true},
      {:bus, in_umbrella: true},
      {:ex_abi, "~> 0.4"},
      {:ethereumex, "0.6.3"},
      {:ecto_sql, "~> 3.4"},
      {:ex_plasma, git: "https://github.com/omisego/ex_plasma.git", ref: "a5d250f4dd36efa7d70b767a306389cf79d572de"},
      {
        :ex_unit_fixtures,
        git: "https://github.com/omisego/ex_unit_fixtures.git", branch: "feature/require_files_not_load", only: [:test]
      },
      {:fake_server, "~> 2.1", only: [:test], runtime: false, override: true},
      {:postgrex, "~> 0.15"},
      {:telemetry, "~> 0.4"},
      {:ex_json_schema, "0.7.4"},
      {:httpoison, "1.6.0"},
      {:hackney, "1.15.2", override: true},
      {:decorator, "~> 1.2"},
      # TEST
      {:exvcr, "~> 0.10", only: :test},
      {:ex_machina, "~> 2.4", only: [:test]},
      {:briefly, git: "https://github.com/CargoSense/briefly.git", only: [:test]},
      {:yaml_elixir, "~> 2.4.0", only: [:test]},
      {:spandex_ecto, "~> 0.6.2"},
      {:spandex, "~> 3.0.1"},
      {:spandex_datadog, "~> 1.0.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
