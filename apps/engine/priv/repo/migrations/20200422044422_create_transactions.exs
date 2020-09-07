defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:tx_bytes, :binary)
      add(:tx_hash, :binary)
      add(:tx_type, :integer)
      add(:deposit_tx_hash, :binary)
      add(:deposit_block_number, :integer)
      add(:kind, :string)

      add(:block_id, references(:blocks))
      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      timestamps(inserted_at: :node_inserted_at, updated_at: :node_updated_at)
    end

    create(index(:transactions, [:block_id]))
    create(unique_index(:transactions, [:deposit_tx_hash, :deposit_block_number]))
    execute("SELECT ecto_manage_updated_at('transactions');")
  end
end
