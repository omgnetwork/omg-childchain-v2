defmodule Engine.DB.PlasmaBlock do
  @moduledoc """
  Ecto schema for you know what.
  """

  use Ecto.Schema
  # import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  schema "plasma_blocks" do
    # Extracted from `output_id`
    field(:hash, :binary)
    field(:nonce, :integer)
    field(:blknum, :integer)
    field(:tx_hash, :binary)
    field(:formed_at_ethereum_height, :integer)
    field(:submitted_at_ethereum_height, :integer)
    field(:gas, :integer)
    field(:attempts_counter, :integer)

    timestamps(type: :utc_datetime)
  end

  @spec get_all_and_submit(pos_integer(), pos_integer(), function()) ::
          {:ok, any()}
          | {:error, any()}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
  def get_all_and_submit(new_height, mined_child_block, submit) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:get_all, __MODULE__, :get_all, [new_height, mined_child_block])
    |> Ecto.Multi.run(:compute_gas, __MODULE__, :compute_gas, [new_height, mined_child_block])
    |> Ecto.Multi.run(:update, __MODULE__, :submit, [new_height, submit])
    |> Engine.Repo.transaction()
  end

  def get_all(repo, %{}, new_height, mined_child_block) do
    query = from(p in __MODULE__, where: p.submitted_at_ethereum_height < ^new_height and p.blknum < ^mined_child_block)
    {:ok, repo.all(query)}
  end

  def compute_gas(repo, %{get_all: plasma_blocks}, new_height, mined_child_block) do
    {:ok,
     Enum.map(plasma_blocks, fn plasma_block ->
       Ecto.Changeset.change(plasma_block,
         gas: plasma_block.gas + 1,
         attempts_counter: plasma_block.attempts_counter + 1,
         submitted_at_ethereum_height: new_height
       )
     end)}
  end

  def submit(repo, %{compute_gas: plasma_blocks}, new_height, submit) do
    {:ok,
     Enum.map(plasma_blocks, fn plasma_block ->
       submit.(%{"hash" => plasma_block.hash, "nonce" => plasma_block.nonce, "gas" => plasma_block.gas})
     end)}
  end
end
