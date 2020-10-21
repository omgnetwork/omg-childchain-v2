defmodule Engine.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add(:tx_bytes, :binary)
      add(:tx_hash, :binary)
      add(:tx_type, :integer)
      add(:tx_index, :integer)

      add(:block_id, references(:blocks))
      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      timestamps(inserted_at: :node_inserted_at, updated_at: :node_updated_at)
    end

    create(index(:transactions, [:block_id]))
    create(unique_index(:transactions, [:tx_type, :tx_hash, :block_id]))
    create(unique_index(:transactions, [:tx_index, :block_id]))
    #create(unique_index(:transactions, :tx_index))
    execute("SELECT ecto_manage_updated_at('transactions');")

    execute("CREATE SEQUENCE tx_index START 1;")

    execute("
    CREATE OR REPLACE FUNCTION fill_in_tx_index() RETURNS trigger AS $$
    BEGIN
      NEW.tx_index := nextval('tx_index') - 1;
      IF (NEW.tx_index > 64000) THEN
          ALTER SEQUENCE tx_index RESTART WITH 1;
      END IF;
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;")

    execute(
      "CREATE TRIGGER fill_in_tx_index BEFORE INSERT ON transactions FOR EACH ROW EXECUTE PROCEDURE fill_in_tx_index();"
    )
  end
end
