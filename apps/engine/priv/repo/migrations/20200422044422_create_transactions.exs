defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:tx_bytes, :binary)
      add(:tx_hash, :binary)
      add(:tx_type, :integer)
      add(:deposit_block_number, :integer)
      add(:kind, :string)

      add(:block_id, references(:plasma_blocks))
      timestamps(type: :timestamptz)
    end

    create(index(:transactions, [:block_id]))
    create(unique_index(:transactions, [:tx_hash, :deposit_block_number]))
  end
end
