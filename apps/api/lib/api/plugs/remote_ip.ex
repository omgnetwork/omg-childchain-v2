defmodule API.Plugs.RemoteIP do
  @moduledoc """
  This plug sets remote_ip from CF-Connecting-IP header.
  """
  import Plug.Conn

  @header_name "cf-connecting-ip"

  def init(options), do: options

  def call(conn, _opts) do
    ips = get_req_header(conn, @header_name)

    parse_and_set_ip(conn, ips)
  end

  defp parse_and_set_ip(conn, [forwarded_ips]) when is_binary(forwarded_ips) do
    left_ip =
      forwarded_ips
      |> String.split(",")
      |> List.first()

    parse_ip(conn, left_ip)
  end

  defp parse_and_set_ip(conn, _ip), do: conn

  defp parse_ip(conn, ip_string) when is_binary(ip_string) do
    parsed_ip =
      ip_string
      |> String.trim()
      |> String.to_charlist()
      |> :inet.parse_address()

    case parsed_ip do
      {:ok, ip} -> %{conn | remote_ip: ip}
      _ -> conn
    end
  end

  defp parse_ip(conn, _), do: conn
end
