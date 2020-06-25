defmodule Engine.Support.TestEntity do
  @moduledoc """
  Can be used in tests to generate a private key/address pair.
  """

  def generate() do
    {:ok, priv} = generate_private_key()
    {:ok, pub} = generate_public_key(priv)
    {:ok, address} = ExPlasma.Crypto.generate_address(pub)

    %{
      priv: priv,
      priv_encoded: ExPlasma.Encoding.to_hex(priv),
      addr: address,
      addr_encoded: ExPlasma.Encoding.to_hex(address)
    }
  end

  defp generate_private_key(), do: {:ok, :crypto.strong_rand_bytes(32)}

  defp generate_public_key(<<priv::binary-size(32)>>) do
    {:ok, der_pub} = get_public_key(priv)
    {:ok, der_to_raw(der_pub)}
  end

  defp der_to_raw(<<4::integer-size(8), data::binary>>), do: data

  defp get_public_key(private_key) do
    case :libsecp256k1.ec_pubkey_create(private_key, :uncompressed) do
      {:ok, public_key} -> {:ok, public_key}
      {:error, reason} -> {:error, to_string(reason)}
    end
  end
end
