defmodule API.Plugs.WatcherVersion do
  @moduledoc """
  Reports metrics based on X-Watcher-Version header
  """

  alias Status.Metric.Datadog
  alias Status.Metric.Event

  @header_name "x-watcher-version"

  def init(options), do: options

  def call(conn, _opts) do
    :ok =
      conn.req_headers
      |> Enum.filter(fn {header, _value} -> header == @header_name end)
      |> Enum.each(fn {_header, x_watcher_version} ->
        Datadog.increment(Event.name(:x_watcher_version, x_watcher_version))
      end)

    conn
  end
end
