defmodule Engine.Repo.Migrations.CreateFees do
  use Ecto.Migration

  def change do
    create table(:fees, primary_key: false) do
      add(:hash, :string, primary_key: true)
      add(:type, :string, primary_key: true)
      add(:term, :binary, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:fees, [:type]))
    create(index(:fees, [:inserted_at]))
  end
end
