defmodule Status.Metric.Statix do
  @moduledoc """
  Useful for overwritting Statix behaviour.
  """
  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Statix
      def connect(), do: :ok

      def increment(_), do: :ok
      def increment(_, _, options \\ []), do: :ok

      def decrement(_, val \\ 1, options \\ []), do: :ok

      def gauge(_, val, options \\ []), do: :ok

      def histogram(_, val, options \\ []), do: :ok

      def timing(_, val, options \\ []), do: :ok

      def measure(key, options \\ [], fun), do: :ok

      def set(key, val, options \\ []), do: :ok

      def event(key, val, options), do: :ok

      def service_check(key, val, options), do: :ok

      def current_conn(), do: %Statix.Conn{sock: __MODULE__}
    end
  end
end
