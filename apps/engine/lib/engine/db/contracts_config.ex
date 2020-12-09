defmodule Engine.DB.ContractsConfig do
  @moduledoc """
  Stores config values related to contracts. At most 1 row exist in this table.

  Fields:

  payment_exit_game - address of the exit game
  eth_vault - address of eth vault
  erc20_vault - address of erc20 vault
  min_exit_period_seconds - min exit period in seconds
  contract_semver - contracts's semver
  child_block_interval - child block interval in seconds
  contract_deployment_height - Ethereum height at which contract was deployed
  """

  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Engine.Repo

  @guard 1

  @required_fields [
    :payment_exit_game,
    :eth_vault,
    :erc20_vault,
    :min_exit_period_seconds,
    :contract_semver,
    :child_block_interval,
    :contract_deployment_height,
    :guard
  ]

  @timestamps_opts [inserted_at: :node_inserted_at]

  @primary_key false
  schema "contracts_config" do
    field(:payment_exit_game, :string)
    field(:eth_vault, :string)
    field(:erc20_vault, :string)
    field(:min_exit_period_seconds, :integer)
    field(:contract_semver, :string)
    field(:child_block_interval, :integer)
    field(:contract_deployment_height, :integer)

    field(:guard, :integer)

    field(:inserted_at, :utc_datetime)

    timestamps()
  end

  def changeset(struct, params) do
    params_with_guard = Map.put(params, :guard, @guard)

    struct
    |> cast(params_with_guard, @required_fields)
    |> validate_required(@required_fields)
  end

  def insert(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def get() do
    Repo.one(from(b in __MODULE__, select: b))
  end
end
