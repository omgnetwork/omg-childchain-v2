defmodule Engine.Trash.Blockchain.Transaction.Signature do
  @moduledoc """
  Defines helper functions for signing and getting the signature
  of a transaction, as defined in Appendix F of the Yellow Paper.

  For any of the following functions, if chain_id is specified,
  it's assumed that we're post-fork and we should follow the
  specification EIP-155 from:

  https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
  Extracted from: https://github.com/exthereum/blockchain
  """

  alias Engine.Trash.Blockchain.Transaction.Hash

  @type private_key :: <<_::256>>

  def sign_transaction(trx, private_key) do
    chain_id = nil

    {v, r, s} =
      trx
      |> Hash.transaction_hash(chain_id)
      |> Hash.sign_hash(private_key, chain_id)

    %{trx | v: v, r: r, s: s}
  end
end
