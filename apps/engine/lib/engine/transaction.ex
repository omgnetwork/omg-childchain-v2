#defmodule Engine.Transaction do
  #@moduledoc """
  #The Transaction Schema. This contains all transactions being sent to the Network
  #with the Generic Transaction Format. There exists two paths for which transactions
  #can appear in the network:

  #* Through the childchain as a payment/transfer transaction.
  #* Through the contracts as a deposit transaction.
  #"""

  #use Ecto.Schema
  #import Ecto.Changeset
  #import Ecto.Query, only: [from: 2]

  ## This is the currently accepted protocol via the Generic Transaction Format.
  ## The metadata MUST be set this value currently.
  #@default_metadata <<0::160>>

  #@error_messages [
    #cannot_be_zero: "can't be zero",
    #exceeds_maximum: "can't exceed maximum value"
  #]

  #schema "transactions" do
    #field(:tx_type, :integer, default: 1)
    #field(:tx_data, :integer, default: 0)
    #field(:metadata, :binary, default: @default_metadata)

    #belongs_to(:block, Engine.Block)
    #has_many(:inputs, Engine.Utxo, foreign_key: :spending_transaction_id)
    #has_many(:outputs, Engine.Utxo, foreign_key: :creating_transaction_id)

    #timestamps(type: :utc_datetime)
  #end

  #@doc """
  #Insert a Transaction into the DB. This can be a tx_bytes(RLP encoded bytes) or
  #a Transaction struct/map.
  #"""
  ## @spec insert(any()) :: %__MODULE__{}
  #def insert(params) do
    #%__MODULE__{} |> changeset(params) |> Engine.Repo.insert()
  #end

  #@doc """
  #Generate a changeset for a Transaction. This will validate:

  #* tx_type, tx_data, metadata exists
  #* if given inputs, that it exists and is unspent
  #"""
  #@spec changeset(%__MODULE__{}, map() | binary()) :: Ecto.Changeset.t()
  #def changeset(struct, txbytes) when is_binary(txbytes) do
    #case ExPlasma.decode(txbytes) do
      #{:ok, transaction} ->
        #changeset(struct, params_from_ex_plasma(transaction))

      #{:error, {field, message}} ->
        #struct |> changeset(%{}) |> add_error(field, @error_messages[message])
    #end
  #end

  #def changeset(struct, %{} = params) do
    #struct
    #|> Engine.Repo.preload(:inputs)
    #|> Engine.Repo.preload(:outputs)
    #|> cast(params, [:tx_type, :tx_data, :metadata])
    #|> validate_required([:tx_type, :tx_data, :metadata])
    #|> cast_assoc(:inputs)
    #|> cast_assoc(:outputs)
    #|> validate_spendable_inputs()
  #end

  ## Validates that the given changesets inputs are correct. To create a transaction with inputs:
  ##   * The utxo position for the input must exist.
  ##   * The utxo position for the input must not have been spent.
  #defp validate_spendable_inputs(changeset) do
    #input_positions = get_input_positions(changeset)

    #unspent_positions =
      #input_positions
      #|> query_for_unspent_utxos()
      #|> Engine.Repo.all()

    #case input_positions -- unspent_positions do
      #[missing_inputs] ->
        #add_error(changeset, :inputs, "input utxos #{missing_inputs} are missing or spent")

      #[] ->
        #changeset
    #end
  #end

  ## The base struct of the Transaction does not contain the calculated utxo position.
  ## So we run the UTXO through ExPlasma to do the calculation for the position.
  #defp get_input_positions(changeset) do
    #changeset |> get_field(:inputs) |> Enum.map(&ExPlasma.Utxo.pos/1)
  #end

  #defp params_from_ex_plasma(struct) do
    #params = Map.from_struct(struct)

    #%{
      #params
      #| inputs: Enum.map(struct.inputs, &Map.from_struct/1),
        #outputs: Enum.map(struct.outputs, &Map.from_struct/1)
    #}
  #end
#end
