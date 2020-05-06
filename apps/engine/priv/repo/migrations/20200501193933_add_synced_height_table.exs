defmodule Engine.Repo.Migrations.AddSyncedHeightTable do
  use Ecto.Migration

  def change do
    create table(:synced_height, primary_key: false) do
      add(:listener, :string, primary_key: true)
      add(:height, :integer)

      timestamps(type: :timestamptz)
    end
  end
end
