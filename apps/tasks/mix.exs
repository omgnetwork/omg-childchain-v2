defmodule Tasks.MixProject do
  @moduledoc """
  If you want to use `iex -S mix run`.
  """
  use Mix.Project

  def project() do
    [
      app: :tasks,
      version: "0.1.0",
      build_path: "../../_build",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      elixirc_paths: ["lib"],
      start_permanent: false,
      deps: []
    ]
  end

  def application() do
    []
  end
end
