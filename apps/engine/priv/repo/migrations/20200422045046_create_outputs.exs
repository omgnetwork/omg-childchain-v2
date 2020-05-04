defmodule Engine.Repo.Migrations.CreateOutputs do
  use Ecto.Migration

  def change do
    create table(:outputs) do
      add :position, :bigint

      add :output_data, :binary
      add :output_id, :binary
      add :output_type, :integer

      add :state, :string, default: "pending"

      add :creating_transaction_id, references(:transactions)
      add :spending_transaction_id, references(:transactions)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:outputs, [:position])
    create index(:outputs, [:creating_transaction_id])
  end
end