defmodule Engine.ReleaseTasks.Contract.Validators do
  @moduledoc false
  @spec address!(String.t(), String.t()) :: no_return() | String.t()
  def address!(address, _) when byte_size(address) == 42 do
    address
  end

  def address!(_, key) do
    raise ArgumentError, message: "#{key} must be set to a valid Ethereum address."
  end

  @spec tx_hash!(String.t(), String.t()) :: no_return() | String.t()
  def tx_hash!(tx_hash, _) when byte_size(tx_hash) == 66 do
    tx_hash
  end

  def tx_hash!(_, key) do
    raise ArgumentError, message: "#{key} must be set to a valid Ethereum transaction hash."
  end

  @spec url!(String.t(), String.t()) :: no_return() | String.t()
  def url!(url, key) when is_binary(url) and byte_size(url) > 0 do
    uri = URI.parse(url)

    case uri.scheme != nil && uri.host |> String.to_charlist() |> :inet_parse.domain() do
      true -> url
      _ -> raise ArgumentError, message: "#{key} must be set to a valid URL."
    end
  end

  def url!(_, key) do
    raise ArgumentError, message: "#{key} must be set to a valid URL."
  end
end
