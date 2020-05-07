defmodule Engine.Repo.Migrations.CreateFeeRulesTable do
  use Ecto.Migration

  def change() do
    create table("fee_rules", primary_key: false) do
      add(:uuid, :uuid, primary_key: true)
      add(:data, :map)

      timestamps(type: :timestamptz)
    end
  end
end
