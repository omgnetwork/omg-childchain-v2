defmodule Engine.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add(:hash, :binary)
      add(:number, :integer)
      add(:state, :string)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      timestamps(inserted_at: :node_inserted_at, updated_at: :node_updated_at)
    end

    create(unique_index(:blocks, [:number]))
    execute("SELECT ecto_manage_updated_at('blocks');")
  end
end
