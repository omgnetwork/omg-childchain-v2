defmodule Engine.Repo.Migrations.CreateFeesTable do
  use Ecto.Migration

  def change() do
    create table("fees", primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:data, :map)
      add(:fee_rules_uuid, references(:fee_rules, column: :uuid, type: :uuid))

      timestamps(type: :timestamptz)
    end
  end
end
