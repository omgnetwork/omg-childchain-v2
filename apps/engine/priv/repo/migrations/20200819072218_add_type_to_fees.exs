defmodule Engine.Repo.Migrations.AddTypeToFees do
  use Ecto.Migration

  def change do
    alter table(:fees) do
      add(:type, :string, null: false)
    end

    create(index(:fees, [:type]))
  end
end
