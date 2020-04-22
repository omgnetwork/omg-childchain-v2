defmodule Engine.DB.Transaction2 do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias __MODULE__

  @type txbytes() :: binary()

  @error_messages [
    cannot_be_zero: "can not be zero",
    exceeds_maximum: "can't exceed maximum value"
  ]

  schema "transaction2s" do
    field(:txbytes, :binary)

    belongs_to(:block, Engine.Block)
    has_many(:inputs, Engine.DB.Output, foreign_key: :spending_transaction_id)
    has_many(:outputs, Engine.DB.Output, foreign_key: :creating_transaction_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, params) do
    struct
    |> Engine.Repo.preload(:inputs)
    |> Engine.Repo.preload(:outputs)
    |> cast(params, [:txbytes])
    |> cast_assoc(:inputs)
    |> cast_assoc(:outputs)
    |> validate_protocol()
  end

  def decode_changeset(txbytes), do: changeset(%__MODULE__{}, decode(txbytes))


  # Does the state-less validation via ExPlasma.
  defp validate_protocol(changeset) do
    results = changeset
    |> get_field(:txbytes)
    |> ExPlasma.decode()
    |> ExPlasma.Transaction.validate()

    case results do
      {:ok, _} ->
        changeset
      {:error, {field, message}} ->
          add_error(changeset, field, @error_messages[message])
    end
  end

  @doc """
  Decodes an rlp encoded transaction bytes into a param for ecto

  ## Example
  """
  @spec decode(txbytes()) :: map()
  def decode(txbytes) when is_binary(txbytes) do
    txbytes 
    |> ExPlasma.decode() 
    |> decode_params()
    |> Map.put(:txbytes, txbytes)
  end

  defp decode_params(%{inputs: inputs, outputs: outputs} = txn) do
    %{ txn |
      inputs: Enum.map(inputs, &Map.from_struct/1),
      outputs: Enum.map(outputs, &Map.from_struct/1)
    }
  end
end
