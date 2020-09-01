defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:tx_bytes, :binary)
      add(:tx_hash, :binary)
      add(:tx_type, :integer)
      add(:kind, :string)

      add(:block_id, references(:blocks))
      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
    end

    create(index(:transactions, [:block_id]))
    execute("SELECT ecto_manage_updated_at('transactions');")
  end
end
