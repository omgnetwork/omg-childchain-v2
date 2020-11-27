defmodule API.Plugs.WatcherVersion do
  @moduledoc """
  Reports metrics based on X-Watcher-Version header
  """

  alias Status.Metric.Event

  @header_name "x-watcher-version"

  # [\d\.]{1,10} - any sequence of dots of digits of length no longer than 10.
  # \+ - plus sign
  # \w{7,7}$ - commit hash, end of string
  @x_watcher_version_value_pattern ~r/[\d\.]{1,10}\+\w{7,7}$/

  def init(options), do: options

  def call(conn, opts) do
    :ok =
      conn.req_headers
      |> Enum.filter(fn {header, _value} -> header == @header_name end)
      |> Enum.filter(fn {_header, value} -> Regex.match?(@x_watcher_version_value_pattern, value) end)
      |> Enum.each(fn {_header, x_watcher_version} ->
        metrics_module = Keyword.fetch!(opts, :metrics_module)
        metrics_module.increment(Event.name(:x_watcher_version, x_watcher_version))
      end)

    conn
  end
end
