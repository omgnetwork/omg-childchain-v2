defmodule API.MixProject do
  use Mix.Project

  def project do
    [
      app: :api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {API.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cors_plug, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.0"},
      {:spandex, "~> 3.0.1"},
      {:spandex_datadog, "~> 1.0.0"},
      {:spandex_phoenix, "~> 0.4.2"}
    ]
  end
end
