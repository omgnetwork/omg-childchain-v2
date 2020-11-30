defmodule Childchain.MixProject do
  use Mix.Project

  def project do
    [
      default_task: "childchain.start",
      apps_path: "apps",
      version: version(),
      start_permanent: Mix.env() == :prod,
      build_path: "_build" <> docker(),
      deps_path: "deps" <> docker(),
      deps: deps(),
      dialyzer: dialyzer(),
      aliases: aliases(),
      releases: [
        childchain: [
          steps: steps(),
          version: version(),
          applications: tools() ++ [engine: :permanent, api: :permanent, status: :permanent, bus: :permanent],
          config_providers: [
            {Engine.ReleaseTasks.Contract, []},
            {Status.ReleaseTasks.Logger, [sentry_logger: Sentry.LoggerBackend, default_logger: Ink]},
            {Status.ReleaseTasks.Sentry, [current_version: version()]},
            {Status.ReleaseTasks.Application, [release: "childchain", current_version: version()]}
          ]
        ]
      ],
      preferred_cli_env: ["test.integration": :test, "test.all": :test]
    ]
  end

  defp aliases() do
    [
      # NB: Think about adding a seed routine here
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["test --no-start"],
      "test.integration": ["test --only integration"],
      "test.all": ["test --include integration"]
    ]
  end

  defp deps do
    [
      {:hackney,
       git: "https://github.com/SergeTupchiy/hackney", ref: "2bf38f92f647de00c4850202f37d4eaab93ed834", override: true},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
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
      plt_add_apps: [:ex_abi, :vmstats, :mix],
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
