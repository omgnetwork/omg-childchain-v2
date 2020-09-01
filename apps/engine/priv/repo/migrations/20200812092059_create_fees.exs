defmodule Engine.Repo.Migrations.CreateFees do
  use Ecto.Migration

  def change do
    create table(:fees, primary_key: false) do
      add(:hash, :string, primary_key: true)
      add(:type, :string, primary_key: true)
      add(:term, :binary)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
    end

    create(index(:fees, [:type]))
    create(index(:fees, [:inserted_at]))

    execute("SELECT ecto_manage_updated_at('fees');")
  end
end
