defmodule Engine.Repo.Migrations.AddPlasmaBlockTable do
  use Ecto.Migration

  def change do
    create table(:plasma_blocks) do
      # keccak hash of transactions
      add(:hash, :binary)
      # transaction order!
      add(:nonce, :integer)
      # plasma block number
      add(:blknum, :integer)
      # submitted transaction hash (gets updated with submitted_at_ethereum_height)
      add(:tx_hash, :binary)
      # at which height did we form the block
      add(:formed_at_ethereum_height, :integer)
      # doesn't mean mined! gets updated every time hash is submitted
      add(:submitted_at_ethereum_height, :integer)
      # gas in wei
      add(:gas, :integer)
      # mining is async and it might fail (like submitted with not enough gas, client error)
      add(:attempts_counter, :integer)
      timestamps(type: :timestamptz)
    end
  end
end
