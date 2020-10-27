defmodule Engine.Repo.Migrations.ApplyBigintWhereNecessary do
  use Ecto.Migration

  def change do
    alter table(:blocks) do
      modify(:nonce, :bigint)
    end

    alter table(:blocks) do
      modify(:blknum, :bigint)
    end

    alter table(:blocks) do
      modify(:formed_at_ethereum_height, :bigint)
    end

    alter table(:blocks) do
      modify(:submitted_at_ethereum_height, :bigint)
    end

    alter table(:blocks) do
      modify(:gas, :bigint)
    end

    alter table(:listener_states) do
      modify(:height, :bigint)
    end
  end
end
