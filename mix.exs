defmodule Childchain.MixProject do
  use Mix.Project
  @sha String.replace(elem(System.cmd("git", ["rev-parse", "--short=7", "HEAD"]), 0), "\n", "")
  @version "#{String.trim(File.read!("VERSION"))}" <> "+" <> @sha
  def project do
    [
      apps_path: "apps",
      version: @version,
      start_permanent: Mix.env() == :prod,
      build_path: "_build" <> docker(),
      deps_path: "deps" <> docker(),
      deps: deps(),
      releases: [
        childchain: [
          steps: steps(),
          version: @version,
          applications: [
            tools: :permanent,
            runtime_tools: :permanent,
            engine: :permanent,
            rpc: :permanent
          ],
          config_providers: []
        ]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end

  defp docker(), do: if(System.get_env("DOCKER"), do: "_docker", else: "")

  defp steps() do
    case Mix.env() do
      :prod -> [:assemble, :tar]
      _ -> [:assemble]
    end
  end
end
