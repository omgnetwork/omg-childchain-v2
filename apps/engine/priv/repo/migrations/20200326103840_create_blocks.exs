defmodule Engine.Repo.Migrations.CreateBlocks do
  use Ecto.Migration

  def change do
    create table(:blocks) do
      add(:hash, :binary)
      add(:number, :integer)
      add(:state, :string)

      add(:nonce, :integer)
      add(:gas, :bigint)
      add(:height, :integer)

      add(:submissions, {:array, :map}, default: [])

      timestamps(type: :timestamptz)
    end

    create(unique_index(:blocks, [:number]))
  end
end
