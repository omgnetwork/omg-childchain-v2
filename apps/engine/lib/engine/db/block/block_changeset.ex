defmodule Engine.DB.Block.BlockChangeset do
  @moduledoc """
  Changesets related to block
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Engine.DB.Block

  @optional_fields [
    :hash,
    :tx_hash,
    :formed_at_ethereum_height,
    :submitted_at_ethereum_height,
    :gas,
    :attempts_counter
  ]
  @required_fields [:nonce, :blknum, :state]

  def new_block_changeset(struct, params) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def submitted(struct, params) do
    struct
    |> put_state(%{state: Block.state_submitted()})
    |> put_gas(params)
    |> put_attempts_counter(params)
    |> put_submitted_at_ethereum_height(params)
  end

  def prepare_for_submission(struct, params) do
    struct
    |> put_hash(params)
    |> put_state(%{state: Block.state_pending_submission()})
  end

  def finalize(struct), do: put_state(struct, %{state: Block.state_finalizing()})

  defp put_state(struct, params) do
    struct
    |> cast(params, [:state])
    |> validate_required([:state])
  end

  defp put_hash(struct, params) do
    struct
    |> cast(params, [:hash])
    |> validate_required([:hash])
  end

  defp put_gas(struct, params) do
    struct
    |> cast(params, [:gas])
    |> validate_required([:gas])
  end

  defp put_attempts_counter(struct, params) do
    struct
    |> cast(params, [:attempts_counter])
    |> validate_required([:attempts_counter])
  end

  defp put_submitted_at_ethereum_height(struct, params) do
    struct
    |> cast(params, [:submitted_at_ethereum_height])
    |> validate_required([:submitted_at_ethereum_height])
  end
end
