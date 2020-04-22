defmodule Engine.Repo.Migrations.CreateTransaction2s do
  use Ecto.Migration

  def change do
    create table(:transaction2s) do
      # meta information
      add :txbytes, :binary

      add :block_id, references(:blocks)
      timestamps(type: :utc_datetime)
    end

    create index(:transaction2s, [:block_id])
  end
end
