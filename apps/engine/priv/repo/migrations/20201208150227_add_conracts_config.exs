defmodule Engine.Repo.Migrations.AddConractsConfig do
  use Ecto.Migration

  def change do
    create table(:contracts_config) do
      add(:payment_exit_game, :binary, null: false)
      add(:eth_vault, :binary, null: false)
      add(:erc20_vault, :binary, null: false)
      add(:min_exit_period_seconds, :integer, null: false)
      add(:contract_semver, :binary, null: false)
      add(:child_block_interval, :integer, null: false)
      add(:contract_deployment_height, :integer, null: false)
      # used in constraints to make sure we have at most one config
      add(:guard, :integer, null: false)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now_utc()"))

      timestamps(inserted_at: :node_inserted_at)
    end

    create(
      constraint(
        :contracts_config,
        :guard_contracts_config_equals_one,
        check: "guard = 1"
      )
    )

    create(unique_index(:contracts_config, [:guard]))
  end
end
