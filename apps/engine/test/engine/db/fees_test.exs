defmodule Feefeed.FeesTest do
  use Engine.DB.DataCase, async: true

  alias Ecto.Changeset
  alias Ecto.UUID
  alias Engine.DB.Fees

  setup do
    rules = insert(:fee_rules)

    {:ok, rules: rules}
  end

  describe "changeset/2" do
    test "casts given params", %{rules: %{uuid: rules_uuid}} do
      params = %{data: %{"some" => "data"}, fee_rules_uuid: rules_uuid, uuid: UUID.generate()}

      assert %Changeset{
               changes: params,
               valid?: true
             } = Fees.changeset(%Fees{}, params)
    end

    test "generates a uuid if not present", %{rules: %{uuid: rules_uuid}} do
      params = %{data: %{"some" => "data"}, fee_rules_uuid: rules_uuid}

      assert %Changeset{
               changes: %{uuid: uuid},
               valid?: true
             } = Fees.changeset(%Fees{}, params)

      assert UUID.cast(uuid) == {:ok, uuid}
    end

    test "validate required fields" do
      assert %Fees{}
             |> Fees.changeset(%{})
             |> errors_on() == %{fee_rules_uuid: ["can't be blank"]}
    end
  end

  describe "fetch_latest/0" do
    test "fetches the latest record when present" do
      fees = insert(:fees)

      assert Fees.fetch_latest() == {:ok, fees}
    end

    test "returns a `:not_found` error when not found" do
      assert Fees.fetch_latest() == {:error, :not_found}
    end
  end

  describe "insert_fees/2" do
    test "inserts the fees", %{rules: %{uuid: rules_uuid}} do
      data = %{"some" => "data"}

      assert {:ok, %Fees{data: ^data, fee_rules_uuid: ^rules_uuid}} = Fees.insert_fees(data, rules_uuid)
    end
  end

  # A helper that transforms changeset errors into a map of messages.

  #     assert {:error, changeset} = Accounts.create_user(%{password: "short"})
  #     assert "password is too short" in errors_on(changeset).password
  #     assert %{password: ["password is too short"]} = errors_on(changeset)

  defp errors_on(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
