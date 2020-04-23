defmodule Engine.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add :hash, :binary
      add :number, :integer
      add :state, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blocks, [:number])
    create unique_index(:blocks, [:state])
  end
end
