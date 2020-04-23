defmodule Engine.DB.Transaction do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias __MODULE__
  alias Engine.DB.Block
  alias Engine.DB.Output

  @type txbytes() :: binary()

  @error_messages [
    cannot_be_zero: "can not be zero",
    exceeds_maximum: "can't exceed maximum value"
  ]

  schema "transactions" do
    field(:txbytes, :binary)

    belongs_to(:block, Block)
    has_many(:inputs, Output, foreign_key: :spending_transaction_id)
    has_many(:outputs, Output, foreign_key: :creating_transaction_id)

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
    |> validate_usable_inputs()
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

  # Validates that the given changesets inputs are correct. To create a transaction with inputs:
  #   * The utxo position for the input must exist.
  #   * The utxo position for the input must not have been spent.
  defp validate_usable_inputs(changeset) do
    input_positions = get_input_positions(changeset)

    unspent_positions =
      input_positions
      |> usable_outputs_for()
      |> Engine.Repo.all()

    case input_positions -- unspent_positions do
      [missing_inputs] ->
        add_error(changeset, :inputs, "input utxos #{missing_inputs} are missing or spent")

      [] ->
        changeset
    end
  end

  # The base struct of the Transaction does not contain the calculated utxo position.
  # So we run the UTXO through ExPlasma to do the calculation for the position.
  defp get_input_positions(changeset) do
    changeset |> get_field(:inputs) |> Enum.map(&get_input_position/1)
  end

  defp get_input_position(%{position: position}), do: position

  def usable_outputs_for(positions) do
    Output.usable()
    |> where([output], output.position in ^positions)
    |> select([output], output.position)
  end
end
