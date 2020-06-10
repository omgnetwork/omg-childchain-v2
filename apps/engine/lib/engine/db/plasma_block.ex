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
    |> Ecto.Multi.run(:get_all, fn repo, changeset ->
      get_all(repo, changeset, new_height, mined_child_block)
    end)
    |> Ecto.Multi.run(:compute_gas_and_submit, fn repo, changeset ->
      compute_gas_and_submit(repo, changeset, new_height, mined_child_block, submit)
    end)
    |> Engine.Repo.transaction()
  end

  defp get_all(repo, _changeset, new_height, mined_child_block) do
    query = from(p in __MODULE__, where: p.submitted_at_ethereum_height < ^new_height and p.blknum < ^mined_child_block)
    {:ok, repo.all(query)}
  end

  def compute_gas_and_submit(repo, %{get_all: []}, _, _, _) do
    {:ok, []}
  end
  def compute_gas_and_submit(repo, %{get_all: [plasma_block | plasma_blocks]}, new_height, mined_child_block, submit) do
    gas = plasma_block.gas + 1
    case submit.(%{"hash" => plasma_block.hash, "nonce" => plasma_block.nonce, "gas" => gas}) do
      :ok ->
           plasma_block
       |> Ecto.Changeset.change(
         gas: gas,
         attempts_counter: plasma_block.attempts_counter + 1,
         submitted_at_ethereum_height: new_height
       )
       |> repo.update!([])
compute_gas_and_submit(repo, %{get_all: plasma_blocks}, new_height, mined_child_block, submit)
      _ ->
compute_gas_and_submit(repo, %{get_all: []}, new_height, mined_child_block, submit)
    end
    # {:ok,
    #  Enum.map(plasma_blocks, fn plasma_block ->
    #    plasma_block
    #    |> Ecto.Changeset.change(
    #      gas: plasma_block.gas + 1,
    #      attempts_counter: plasma_block.attempts_counter + 1,
    #      submitted_at_ethereum_height: new_height
    #    )
    #    |> repo.update!([])
    #  end)}
  end



  defp submit_to_vault(_repo, plasma_blocks, submit) do
    # processed_plasma_blocks =
    #   Enum.reduce_while(plasma_blocks, [], fn plasma_block, acc ->
    #     case submit.(%{"hash" => plasma_block.hash, "nonce" => plasma_block.nonce, "gas" => plasma_block.gas}) do
    #       :ok -> {:cont, [plasma_block | acc]}
    #       _ -> {:halt, acc}
    #     end
    #   end)

    # {:error, processed_plasma_blocks}
  end
end
