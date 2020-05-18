defmodule Engine.Trash.Blockchain.Transaction.Hash do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  Extracted from: https://github.com/exthereum/blockchain
  """

  alias Engine.Trash.Blockchain.BitHelper
  alias Engine.Trash.Blockchain.Transaction

  @base_recovery_id 27
  @base_recovery_id_eip_155 35
  @type private_key :: <<_::256>>
  @type hash_v :: integer()
  @type hash_r :: integer()
  @type hash_s :: integer()
  @doc """
  Returns a hash of a given transaction according to the
  formula defined in Eq.(214) and Eq.(215) of the Yellow Paper.

  Note: As per EIP-155 (https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md),
        we will append the chain-id and nil elements to the serialized transaction.

  """

  def transaction_hash(trx, chain_id) do
    trx
    |> Transaction.serialize(false)
    # See EIP-155
    |> Kernel.++(if chain_id, do: [:binary.encode_unsigned(chain_id), <<>>, <<>>], else: [])
    |> ExRLP.encode()
    |> BitHelper.kec()
  end

  @doc """
  Returns a ECDSA signature (v,r,s) for a given hashed value.

  This implementes Eq.(207) of the Yellow Paper.

  """
  def sign_hash(hash, private_key, chain_id) do
    {:ok, <<r::size(256), s::size(256)>>, recovery_id} =
      :libsecp256k1.ecdsa_sign_compact(hash, private_key, :default, <<>>)

    # Fork Ψ EIP-155
    {
      if chain_id do
        chain_id * 2 + @base_recovery_id_eip_155 + recovery_id
      else
        @base_recovery_id + recovery_id
      end,
      r,
      s
    }
  end
end
