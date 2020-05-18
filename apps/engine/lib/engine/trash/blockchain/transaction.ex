defmodule Engine.Trash.Blockchain.Transaction do
  @moduledoc """
  This module encodes the transaction object, defined in Section 4.3
  of the Yellow Paper (http://gavwood.com/Paper.pdf). We are focused
  on implementing 𝛶, as defined in Eq.(1).
  Extracted from: https://github.com/exthereum/blockchain
  """
  alias Engine.Trash.Blockchain.BitHelper

  defstruct nonce: 0,

            # Tn
            # Tp
            gas_price: 0,
            # Tg
            gas_limit: 0,
            # Tt
            to: <<>>,
            # Tv
            value: 0,
            # Tw
            v: nil,
            # Tr
            r: nil,
            # Ts
            s: nil,
            # Ti
            init: <<>>,
            # Td
            data: <<>>

  @type t :: %__MODULE__{
          nonce: integer(),
          gas_price: integer(),
          gas_limit: integer(),
          to: <<_::160>> | <<_::0>>,
          value: integer(),
          v: integer(),
          r: integer(),
          s: integer(),
          init: binary(),
          data: binary()
        }

  @spec serialize(t) :: ExRLP.t()
  def serialize(trx, include_vrs \\ true) do
    base = [
      BitHelper.encode_unsigned(trx.nonce),
      BitHelper.encode_unsigned(trx.gas_price),
      BitHelper.encode_unsigned(trx.gas_limit),
      trx.to,
      BitHelper.encode_unsigned(trx.value),
      if(trx.to == <<>>, do: trx.init, else: trx.data)
    ]

    if include_vrs do
      base ++
        [
          BitHelper.encode_unsigned(trx.v),
          BitHelper.encode_unsigned(trx.r),
          BitHelper.encode_unsigned(trx.s)
        ]
    else
      base
    end
  end
end
