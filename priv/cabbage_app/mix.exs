defmodule CabbageApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :cabbage_app,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:eip_55, "~> 0.1"},
      {:ex_plasma, git: "https://github.com/omisego/ex_plasma.git"},
      {:ethereumex, "~> 0.6.0"},
      {:ex_abi, "~> 0.4.0"},
      {:ex_rlp, "~> 0.5.3"},
      {:libsecp256k1,
       git: "https://github.com/omisego/libsecp256k1.git", branch: "elixir-only", override: true},
      {:poison, "~> 3.0"},
      {:cabbage, "~> 0.3.0"}
    ]
  end
end
