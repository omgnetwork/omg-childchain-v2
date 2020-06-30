defmodule Engine.DB.Transaction.ValidatorTest do
  use Engine.DB.DataCase, async: true

  alias Engine.DB.Transaction
  alias Engine.DB.Transaction.Validator
  alias Engine.Repo
  alias ExPlasma.Builder
  alias ExPlasma.Output

  describe "validate_inputs/1" do
    test "associate inputs if all inputs are usable" do
      i_1 = build_input(1, 0, 0)
      i_1_in_db = insert(:output, Map.put(i_1, :state, "confirmed"))

      i_2 = build_input(2, 0, 0)
      i_2_in_db = insert(:output, Map.put(i_2, :state, "confirmed"))

      changeset =
        [i_1, i_2]
        |> build_changeset_with_inputs()
        |> Validator.validate_inputs()

      assert changeset.valid?
      assert get_field(changeset, :inputs) == [i_1_in_db, i_2_in_db]
    end

    test "returns an error if inputs don't exist" do
      i_1 = build_input(1, 0, 0)
      i_2 = build_input(2, 0, 0)
      i_3 = build_input(3, 0, 0)

      insert(:output, Map.put(i_1, :state, "confirmed"))

      changeset =
        [i_1, i_2, i_3]
        |> build_changeset_with_inputs()
        |> Validator.validate_inputs()

      refute changeset.valid?
      assert {"inputs [2000000000, 3000000000] are missing, spent, or not yet available", _} = changeset.errors[:inputs]
    end

    test "returns an error if inputs are spent" do
      i_1 = build_input(1, 0, 0)
      i_2 = build_input(2, 0, 0)

      insert(:output, Map.put(i_1, :state, "confirmed"))
      insert(:output, Map.put(i_2, :state, "spent"))

      changeset =
        [i_1, i_2]
        |> build_changeset_with_inputs()
        |> Validator.validate_inputs()

      refute changeset.valid?
      assert {"inputs [2000000000] are missing, spent, or not yet available", _} = changeset.errors[:inputs]
    end

    test "returns an error if inputs are pending" do
      i_1 = build_input(1, 0, 0)
      i_2 = build_input(2, 0, 0)

      insert(:output, Map.put(i_1, :state, "confirmed"))
      insert(:output, Map.put(i_2, :state, "pending"))

      changeset =
        [i_1, i_2]
        |> build_changeset_with_inputs()
        |> Validator.validate_inputs()

      refute changeset.valid?
      assert {"inputs [2000000000] are missing, spent, or not yet available", _} = changeset.errors[:inputs]
    end
  end

  describe "validate_protocol/1" do
    test "returns the changeset unchanged when valid" do
      stateless_valid_tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
        |> ExPlasma.encode()

      changeset = change(%Transaction{}, %{tx_bytes: stateless_valid_tx_bytes})
      validated_changeset = Validator.validate_protocol(changeset)

      assert validated_changeset.valid?
      assert validated_changeset == changeset
    end

    test "returns the changeset with an error if when invalid" do
      stateless_invalid_tx_bytes =
        [tx_type: 1]
        |> Builder.new()
        |> Builder.add_input(blknum: 1, txindex: 0, oindex: 0)
        |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 0)
        |> ExPlasma.encode()

      validated_changeset =
        %Transaction{}
        |> change(%{tx_bytes: stateless_invalid_tx_bytes})
        |> Validator.validate_protocol()

      refute validated_changeset.valid?
      assert {"can not be zero", _} = validated_changeset.errors[:amount]
    end
  end

  describe "validate_statefully/1" do
    test "returns the changeset unchanged when already invalid" do
      changeset =
        %Transaction{}
        |> change()
        |> Ecto.Changeset.add_error(:some_key, "some message")

      validated_changeset = Validator.validate_statefully(changeset, 1, Transaction.kind_transfer(), %{})
      assert validated_changeset == changeset
    end

    test "returns the changeset unchanged when it's a deposit" do
      changeset = change(%Transaction{})

      validated_changeset = Validator.validate_statefully(changeset, 1, Transaction.kind_deposit(), %{})
      assert validated_changeset == changeset
    end

    test "returns the changeset unchanged when valid" do
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

      changeset =
        %Transaction{}
        |> change()
        |> put_assoc(:inputs, inputs)
        |> put_assoc(:outputs, outputs)

      validated_changeset = Validator.validate_statefully(changeset, 1, Transaction.kind_transfer(), fees)

      assert validated_changeset.valid?
      assert validated_changeset == changeset
    end

    test "returns the changeset with an error when invalid" do
      token = <<0::160>>
      fees = %{token => [10]}

      inputs = [
        build(:output, %{
          output_data: %{output_guard: <<1::160>>, token: token, amount: 2},
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
        |> change()
        |> put_assoc(:inputs, inputs)
        |> put_assoc(:outputs, outputs)

      validated_changeset = Validator.validate_statefully(changeset, 1, Transaction.kind_transfer(), fees)

      refute validated_changeset.valid?
      assert {"fees are not covered by inputs", _} = validated_changeset.errors[:inputs]
    end
  end

  defp build_input(blknum, oindex, txindex) do
    map = %{blknum: blknum, oindex: oindex, txindex: txindex}
    output_id = Map.put(map, :position, Output.Position.pos(map))

    Map.from_struct(%Output{output_id: output_id})
  end

  defp build_changeset_with_inputs(inputs) do
    %Transaction{}
    |> Repo.preload(:inputs)
    |> cast(%{inputs: inputs}, [])
    |> cast_assoc(:inputs)
  end
end