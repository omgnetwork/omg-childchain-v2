defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:tx_bytes, :binary)
      add(:tx_hash, :binary)

      add(:block_id, references(:blocks))
      timestamps(type: :utc_datetime)
    end

    create(index(:transactions, [:block_id]))
  end
end
