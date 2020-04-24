defmodule Engine.DB.Transaction do
  @moduledoc """
  The Transaction record. This is one of the main entry points for the system, specifically accepting
  transactions into the Childchain as `txbytes`. This expands those bytes into:

  * `txbytes` - A binary of a transaction encoded by RLP.
  * `inputs`  - The outputs that the transaction is acting on, and changes state e.g marked as "spent"
  * `outputs` - The newly created outputs

  More information is contained in the `txbytes`. However, to keep the Childchain _lean_, we extract
  data onto the record as needed.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Engine.DB.Block
  alias Engine.DB.Output
  alias Engine.Repo

  @type txbytes :: binary

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

  @doc """
  Query all transactions that have not been formed into a block.
  """
  def pending(), do: from(t in __MODULE__, where: is_nil(t.block_id))

  @doc """
  The main action of the system. Takes txbytes and forms the appropriate
  associations for the transaction and outputs and runs the changeset.
  """
  @spec decode(txbytes) :: Ecto.Changeset.t()
  def decode(txbytes) when is_binary(txbytes) do
    params =
      txbytes
      |> ExPlasma.decode()
      |> decode_params()
      |> Map.put(:txbytes, txbytes)

    changeset(%__MODULE__{}, params)
  end

  defp decode_params(%{inputs: inputs, outputs: outputs} = txn) do
    %{txn | inputs: Enum.map(inputs, &Map.from_struct/1), outputs: Enum.map(outputs, &Map.from_struct/1)}
  end

  # TODO: We should extract the PaymentV1 specific behaviors out, like
  #
  # * checking if the input is not spent.
  # * checking if the input/output amounts are the same.
  defp changeset(struct, params) do
    struct
    |> Repo.preload(:inputs)
    |> Repo.preload(:outputs)
    |> cast(params, [:txbytes])
    |> cast_assoc(:inputs)
    |> cast_assoc(:outputs)
    |> validate_protocol()
    |> associate_usable_inputs()
  end

  # Validate the transaction bytes with the generic transaction format protocol.
  #
  # see ExPlasma.Transaction.validate/1
  defp validate_protocol(changeset) do
    results =
      changeset
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

  # Validates that the given changesets inputs are correct. To create a transaction with inputs:
  #   * The position for the input must exist.
  #   * The position for the input must not have been spent.
  #
  # If so, associate the records to this transaction.
  defp associate_usable_inputs(changeset) do
    input_positions = get_input_positions(changeset)
    inputs = input_positions |> usable_outputs_for() |> Repo.all()

    case input_positions -- Enum.map(inputs, & &1.position) do
      [missing_inputs] ->
        add_error(changeset, :inputs, "input #{missing_inputs} are missing or spent")

      [] ->
        put_change(changeset, :inputs, inputs)
    end
  end

  defp get_input_positions(changeset) do
    changeset |> get_field(:inputs) |> Enum.map(&get_input_position/1)
  end

  defp get_input_position(%{position: position}), do: position

  # Return all confirmed outputs that have the given positions.
  defp usable_outputs_for(positions) do
    Output.usable()
    |> where([output], output.position in ^positions)
  end
end
