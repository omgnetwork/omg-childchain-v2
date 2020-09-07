defmodule Engine.Repo.Migrations.CreateOutputs do
  use Ecto.Migration

  def change do
    create table(:outputs) do
      add(:position, :bigint)

      add(:output_data, :binary)
      add(:output_id, :binary)
      add(:output_type, :integer)

      add(:state, :string, default: "pending")

      add(:creating_transaction_id, references(:transactions))
      add(:spending_transaction_id, references(:transactions))

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      timestamps(inserted_at: :node_inserted_at, updated_at: :node_updated_at)
    end

    create(unique_index(:outputs, [:position]))
    create(index(:outputs, [:creating_transaction_id]))
    execute("SELECT ecto_manage_updated_at('outputs');")
  end
end
