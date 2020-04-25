defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :txbytes, :binary
      add :txhash, :binary

      add :block_id, references(:blocks)
      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:block_id])
  end
end
