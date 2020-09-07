defmodule Engine.Repo.Migrations.CreateBlocksTable do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      # keccak hash of transactions
      add(:hash, :binary)
      # transaction order!
      add(:nonce, :integer, null: false)
      # plasma block number
      add(:blknum, :integer, null: false)
      # submitted transaction hash (gets updated with submitted_at_ethereum_height)
      add(:tx_hash, :binary)
      # at which height did we form the block
      add(:formed_at_ethereum_height, :integer)
      # doesn't mean mined! gets updated every time hash is submitted
      add(:submitted_at_ethereum_height, :integer)
      # gas in wei
      add(:gas, :integer)
      # mining is async and it might fail (like submitted with not enough gas, client error)
      add(:attempts_counter, :integer, default: 0, null: false)
      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      timestamps(inserted_at: :node_inserted_at, updated_at: :node_updated_at)
    end

    create(unique_index(:blocks, :blknum))
    create(unique_index(:blocks, :hash))

    create(
      constraint(
        :blocks,
        :block_number_nonce,
        check: "blknum = nonce * 1000"
      )
    )

    execute("SELECT ecto_manage_updated_at('plasma_blocks');")
  end
end
