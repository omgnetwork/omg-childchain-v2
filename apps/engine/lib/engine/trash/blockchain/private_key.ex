defmodule Engine.Trash.Blockchain.PrivateKey do
  @moduledoc """
  Extracts private key from environment
  """
  require Integer

  def get() do
    private_key = System.get_env("PRIVATE_KEY")
    load_raw_hex(private_key)
  end

  @spec load_raw_hex(String.t()) :: binary()
  defp load_raw_hex("0x" <> hex_data), do: load_raw_hex(hex_data)

  defp load_raw_hex(hex_data) when Integer.is_odd(byte_size(hex_data)) do
    load_raw_hex("0" <> hex_data)
  end

  defp load_raw_hex(hex_data) do
    Base.decode16!(hex_data, case: :mixed)
  end
end
