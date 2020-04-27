defmodule Status.ReleaseTasks.Application do
  @moduledoc false
  @behaviour Config.Provider

  def init(args) do
    args
  end

  def load(config, release: release, current_version: current_version) do
    Config.Reader.merge(config, status: [release: release, current_version: current_version])
  end
end
