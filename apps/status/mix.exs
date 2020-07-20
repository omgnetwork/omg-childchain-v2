defmodule Status.Mixfile do
  use Mix.Project

  def project() do
    [
      app: :status,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  def application() do
    [
      mod: {Status.Application, []},
      extra_applications: [:logger, :sasl, :os_mon, :statix, :telemetry],
      included_applications: [:vmstats]
    ]
  end

  defp deps() do
    [
      {:observer_cli, "~> 1.5"},
      {:recon, "~> 2.5"},
      {:telemetry, "~> 0.4.1"},
      {:sentry, "~> 7.0"},
      {:statix, git: "https://github.com/omisego/statix.git", branch: "otp-21.3.8.4-support-global-tag-patch"},
      {:spandex_datadog, "~> 1.0.0"},
      {:decorator, "~> 1.2"},
      {:vmstats, "~> 2.3", runtime: false},
      {:ink, "~> 1.1"}
    ]
  end
end
