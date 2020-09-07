defmodule Engine.Repo.Migrations.CreateListenerStates do
  use Ecto.Migration

  def change do
    create table(:listener_states, primary_key: false) do
      add(:listener, :string, primary_key: true)
      add(:height, :integer)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      add(:updated_at, :utc_datetime, null: false, default: fragment("now_utc()"))
      timestamps(inserted_at: :node_inserted_at, updated_at: :node_updated_at)
    end

    execute("SELECT ecto_manage_updated_at('listener_states');")
  end
end
