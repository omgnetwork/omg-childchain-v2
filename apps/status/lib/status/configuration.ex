defmodule Status.Configuration do
  @moduledoc false

  alias Status.Metric.Tracer
  @spec tracer() :: Keyword.t()
  def tracer() do
    Application.get_env(:status, Tracer)
  end

  @spec spandex_datadog() :: Keyword.t()
  def spandex_datadog() do
    Application.get_all_env(:spandex_datadog)
  end

  @spec release() :: String.t()
  def release() do
    Application.get_env(:status, :release)
  end

  @spec current_version() :: String.t()
  def current_version() do
    Application.get_env(:status, :current_version)
  end

  @spec statix() :: Keyword.t()
  def statix() do
    Application.get_all_env(:statix)
  end
end
