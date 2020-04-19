defmodule Status.Metric.VmstatsSink do
  @moduledoc """
  Interface implementation.
  """
  @behaviour :vmstats_sink

  alias Status.Metric.Datadog

  @type vm_stat :: {:vmstats_sup, :start_link, [any(), ...]}

  @doc """
  Returns child_specs for the given metric setup, to be included e.g. in Supervisor's children.
  """
  @spec prepare_child() :: %{id: :vmstats_sup, start: vm_stat()}
  def prepare_child() do
    %{id: :vmstats_sup, start: {:vmstats_sup, :start_link, [__MODULE__, base_key()]}}
  end

  defp base_key(), do: Application.get_env(:vmstats, :base_key)
  # statix currently does not support `count` or `monotonic_count`, only increment and decrement
  # because of that, we're sending counters as gauges
  def collect(:counter, key, value), do: _ = Datadog.gauge(key, value)

  def collect(:gauge, key, value), do: _ = Datadog.gauge(key, value)

  def collect(:timing, key, value), do: _ = Datadog.timing(key, value)
end
