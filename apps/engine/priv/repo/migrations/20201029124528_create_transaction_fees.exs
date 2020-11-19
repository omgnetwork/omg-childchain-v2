defmodule Engine.Repo.Migrations.CreateTransactionFees do
  use Ecto.Migration

  def change do
    create table(:transaction_fees) do
      add(:transaction_id, references(:transactions, on_delete: :delete_all))
      add(:currency, :binary, null: false)
      add(:amount, :bigint, null: false)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))

      timestamps(inserted_at: :node_inserted_at)
    end

    create(index(:transaction_fees, [:transaction_id]))
    create(unique_index(:transaction_fees, [:transaction_id, :currency]))
  end
end
