defmodule Engine.DB.Transaction.ValidatorTest do
  use Engine.DB.DataCase, async: true

  alias Engine.DB.Output, as: DbOutput
  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.Validator
  alias Engine.Repo
  alias ExPlasma.Builder
  alias ExPlasma.Output

  describe "associate_inputs/2" do
    test "associate inputs if all inputs are usable in the correct order" do
      %{output_id: output_id_1} = insert(:deposit_output)
      %{output_id: %{position: i_1_position}} = i_1 = build_input(output_id_1)

      %{output_id: output_id_2} = insert(:deposit_output)
      %{output_id: %{position: i_2_position}} = i_2 = build_input(output_id_2)

      %{output_id: output_id_3} = insert(:deposit_output)
      %{output_id: %{position: i_3_position}} = i_3 = build_input(output_id_3)

      %{output_id: output_id_4} = insert(:deposit_output)
      %{output_id: %{position: i_4_position}} = i_4 = build_input(output_id_4)

      changeset =
        %Transaction{}
        |> change(%{})
        |> Validator.associate_inputs(%{inputs: [i_3, i_2, i_4, i_1]})

      assert changeset.valid?

      assert [
               %{position: ^i_3_position},
               %{position: ^i_2_position},
               %{position: ^i_4_position},
               %{position: ^i_1_position}
             ] = get_field(changeset, :inputs)
    end

    test "returns an error if inputs don't exist" do
      %{output_id: output_id_1} = insert(:deposit_output)
      i_1 = build_input(output_id_1)
      %{output_id: %{position: i_2_position}} = i_2 = build_input(2, 0, 0)
      %{output_id: %{position: i_3_position}} = i_3 = build_input(3, 0, 0)

      changeset =
        %Transaction{}
        |> change(%{})
        |> Validator.associate_inputs(%{inputs: [i_1, i_2, i_3]})

      refute changeset.valid?

      assert changeset.errors[:inputs] ==
               {"inputs [#{i_2_position}, #{i_3_position}] are missing, spent, or not yet available", []}
    end

    test "returns an error if inputs are spent" do
      %{output_id: output_id_1} = insert(:deposit_output)
      %{output_id: output_id_2, state: :spent} = :deposit_output |> insert() |> DbOutput.spend(%{}) |> Repo.update!()

      i_1 = build_input(output_id_1)
      %{output_id: %{position: i_2_position}} = i_2 = build_input(output_id_2)

      changeset =
        %Transaction{}
        |> change(%{})
        |> Validator.associate_inputs(%{inputs: [i_1, i_2]})

      refute changeset.valid?
      assert changeset.errors[:inputs] == {"inputs [#{i_2_position}] are missing, spent, or not yet available", []}
    end
  end

  describe "validate_protocol/1" do
    test "returns the changeset unchanged when valid" do
      signed_tx =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
        |> Builder.sign!([])

      changeset = change(%Transaction{}, %{tx_bytes: ExPlasma.encode!(signed_tx), signed_tx: signed_tx})
      validated_changeset = Validator.validate_protocol(changeset)

      assert validated_changeset.valid?
      assert validated_changeset == changeset
    end

    test "returns the changeset with an error if when invalid" do
      signed_tx =
        ExPlasma.payment_v1()
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 0)
        |> Builder.sign!([])

      validated_changeset =
        %Transaction{}
        |> change(%{tx_bytes: ExPlasma.encode!(signed_tx), signed_tx: signed_tx})
        |> Validator.validate_protocol()

      refute validated_changeset.valid?
      assert {"Cannot be zero", _} = validated_changeset.errors[:amount]
    end
  end

  describe "validate_statefully/1" do
    test "returns the changeset unchanged when already invalid" do
      changeset =
        %Transaction{}
        |> change()
        |> Ecto.Changeset.add_error(:some_key, "some message")

      params = %{tx_type: 1}
      validated_changeset = Validator.validate_statefully(changeset, params)
      assert validated_changeset == changeset
    end

    test "returns the changeset with transaction fees" do
      token = <<0::160>>
      alice = <<1::160>>
      bob = <<2::160>>
      fees = %{token => [1, 10]}

      inputs = [
        build(:output, %{
          output_data: %{output_guard: alice, token: token, amount: 2},
          output_id: %{blknum: 1, oindex: 0, txindex: 0}
        }),
        build(:output, %{
          output_data: %{output_guard: alice, token: token, amount: 3},
          output_id: %{blknum: 2, oindex: 0, txindex: 0}
        })
      ]

      outputs = [
        build(:output, %{
          output_data: %{output_guard: bob, token: token, amount: 4}
        })
      ]

      transaction_fees = [build(:transaction_fee, %{amount: 1, currency: token})]

      changeset =
        %Transaction{}
        |> change(%{witnesses: [alice, alice]})
        |> put_assoc(:inputs, inputs)
        |> put_assoc(:outputs, outputs)
        |> put_assoc(:fees, transaction_fees)

      params = %{tx_type: 1, fees: fees}
      validated_changeset = Validator.validate_statefully(changeset, params)

      assert validated_changeset.valid?
      assert validated_changeset == changeset
    end

    test "returns the changeset with an error when invalid" do
      token = <<0::160>>
      alice = <<1::160>>
      fees = %{token => [10]}

      inputs = [
        build(:output, %{
          output_data: %{output_guard: alice, token: token, amount: 2},
          output_id: %{blknum: 1, oindex: 0, txindex: 0}
        })
      ]

      outputs = [
        build(:output, %{
          output_data: %{output_guard: <<2::160>>, token: token, amount: 2}
        })
      ]

      changeset =
        %Transaction{}
        |> change(%{witnesses: [alice]})
        |> put_assoc(:inputs, inputs)
        |> put_assoc(:outputs, outputs)

      params = %{tx_type: 1, fees: fees}
      validated_changeset = Validator.validate_statefully(changeset, params)

      refute validated_changeset.valid?
      assert {"Fees are not covered by inputs", _} = validated_changeset.errors[:inputs]
    end
  end

  defp build_input(blknum, txindex, oindex) do
    output_id = Output.Position.new(blknum, txindex, oindex)

    Map.from_struct(%Output{output_id: output_id})
  end

  defp build_input(output_id), do: output_id |> Output.decode_id!() |> Map.from_struct()
end
