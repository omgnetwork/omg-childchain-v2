defmodule Engine.Repo.Migrations.CreateUtxos do
  use Ecto.Migration

  def change do
    create table(:utxos) do
      # UTXO position information
      add(:pos, :bigint)
      add(:blknum, :integer)
      add(:txindex, :integer)
      add(:oindex, :integer)

      # UTXO output information
      add(:output_type, :integer, default: 1)
      add(:owner, :binary)
      add(:currency, :binary)
      add(:amount, :bigint, null: false, default: 0)

      add(:state, :string, default: "")

      add(:creating_transaction_id, references(:transactions))
      add(:spending_transaction_id, references(:transactions))

      timestamps()
    end

    create(unique_index(:utxos, [:pos]))
    create(index(:utxos, [:blknum]))
    create(index(:utxos, [:owner, :currency]))
  end
end
