defmodule Engine.Encoding do
  @moduledoc false

  @spec to_hex(binary | non_neg_integer) :: binary
  def to_hex(raw) when is_binary(raw), do: "0x" <> Base.encode16(raw, case: :lower)
  def to_hex(int) when is_integer(int), do: "0x" <> Integer.to_string(int, 16)

  @spec from_hex(<<_::16, _::_*8>>) :: binary
  def from_hex("0x" <> encoded), do: Base.decode16!(encoded, case: :lower)

  @spec int_from_hex(<<_::16, _::_*8>>) :: non_neg_integer
  def int_from_hex("0x" <> encoded) do
    {return, ""} = Integer.parse(encoded, 16)
    return
  end
end
