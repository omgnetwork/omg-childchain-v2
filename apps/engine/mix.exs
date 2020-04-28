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
      {:bus, in_umbrella: true},
      {:ex_abi, "~> 0.2"},
      {:ethereumex, "0.6.1"},
      {:ecto_sql, "~> 3.1"},
      {:ex_plasma, git: "https://github.com/omisego/ex_plasma.git"},
      {:postgrex, "~> 0.14"},
      {:telemetry, "~> 0.4"},
      # TEST
      {:ex_machina, "~> 2.4", only: [:test]},
      {:briefly, "~> 0.3.0", only: [:test]},
      {:yaml_elixir, "~> 2.4.0", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
