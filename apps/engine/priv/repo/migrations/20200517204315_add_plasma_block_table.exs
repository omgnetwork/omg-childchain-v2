defmodule Engine.Repo.Migrations.AddPlasmaBlockTable do
  use Ecto.Migration

  def change do
    create table(:plasma_blocks) do
      # keccak hash of transactions
      add(:hash, :binary, null: false)
      # transaction order!
      add(:nonce, :integer, null: false)
      # plasma block number
      add(:blknum, :integer, null: false)
      # submitted transaction hash (gets updated with submitted_at_ethereum_height)
      add(:tx_hash, :binary, null: false)
      # at which height did we form the block
      add(:formed_at_ethereum_height, :integer, null: false)
      # doesn't mean mined! gets updated every time hash is submitted
      add(:submitted_at_ethereum_height, :integer)
      # gas in wei
      add(:gas, :integer, null: false)
      # mining is async and it might fail (like submitted with not enough gas, client error)
      add(:attempts_counter, :integer, default: 0, null: false)
      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
    end

    execute("SELECT ecto_manage_updated_at('plasma_blocks');")
  end
end
