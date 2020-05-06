defmodule Engine.Repo.Migrations.CreateListenerStates do
  use Ecto.Migration

  def change do
    create table(:listener_states, primary_key: false) do
      add(:listener, :string, primary_key: true)
      add(:height, :integer)

      timestamps(type: :utc_datetime)
    end
  end
end
