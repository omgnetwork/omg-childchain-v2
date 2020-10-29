defmodule Engine.Repo.Migrations.CreatePaidFees do
  use Ecto.Migration

  def change do
    create table(:paid_fees) do
      add(:transaction_id, references(:transactions), null: false)
      add(:currency, :binary, null: false)
      add(:amount, :bigint, null: false)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))

      timestamps(inserted_at: :node_inserted_at)
    end

    create(index(:paid_fees, [:transaction_id]))
    create(unique_index(:paid_fees, [:transaction_id, :currency]))
  end
end
