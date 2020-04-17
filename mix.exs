defmodule Childchain.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: version(),
      start_permanent: Mix.env() == :prod,
      build_path: "_build" <> docker(),
      deps_path: "deps" <> docker(),
      deps: deps(),
      dialyzer: dialyzer(),
      releases: [
        childchain: [
          steps: steps(),
          version: version(),
          applications: tools() ++ [engine: :permanent, rpc: :permanent],
          config_providers: [{Engine.ReleaseTasks.Contract, []}]
        ]
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.0.0", only: [:dev], runtime: false}
    ]
  end

  defp docker() do
    case System.get_env("DOCKER") do
      nil -> ""
      _ -> "_docker"
    end
  end

  defp steps() do
    case Mix.env() do
      :prod -> [:assemble, :tar]
      _ -> [:assemble]
    end
  end

  defp dialyzer() do
    paths =
      "apps"
      |> File.ls!()
      |> Enum.map(fn app ->
        "_build#{docker()}/#{Mix.env()}/lib/#{app}/ebin"
      end)

    [
      flags: [
        :error_handling,
        :race_conditions,
        :underspecs,
        :unknown,
        :unmatched_returns
      ],
      ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true,
      plt_add_apps: [:keccakf1600, :ex_abi],
      paths: paths
    ]
  end

  defp tools() do
    case Mix.env() do
      :prod ->
        [tools: :permanent, runtime_tools: :permanent]

      _ ->
        [
          observer: :permanent,
          wx: :permanent,
          tools: :permanent,
          runtime_tools: :permanent
        ]
    end
  end

  defp version() do
    "#{String.trim(File.read!("VERSION"))}" <> "+" <> sha()
  end

  defp sha() do
    git_sha = System.cmd("git", ["rev-parse", "--short=7", "HEAD"])
    String.replace(elem(git_sha, 0), "\n", "")
  end
end
