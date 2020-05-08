defmodule Engine.Feefeed.Rules.Worker.UpdateTest do
  use Engine.DB.DataCase, async: true

  alias Engine.DB.Fees
  alias Engine.Feefeed.Rules.Worker.Update

  test "updates the fees if changed" do
    assert Fees.fetch_latest() == {:error, :not_found}

    %{uuid: fee_rules_uuid} = fee_rules = insert(:fee_rules)

    Update.fees(fee_rules_uuid, fee_rules.data)

    assert {:ok, %{data: %{}, uuid: _, fee_rules_uuid: ^fee_rules_uuid}} = Fees.fetch_latest()
  end

  test "does nothing if fees didn't change" do
    %{uuid: fee_rules_uuid} = fee_rules = insert(:fee_rules)

    Update.fees(fee_rules_uuid, fee_rules.data)

    assert {:ok, fees} = Fees.fetch_latest()

    Update.fees(fee_rules_uuid, fee_rules.data)

    assert Fees.fetch_latest() == {:ok, fees}
  end

  test "crashes the server if the rule is invalid" do
    params =
      :fee_rules
      |> params_for()
      |> Kernel.put_in(
        [:data, "1", "0x0000000000000000000000000000000000000000", "type"],
        "invalid"
      )

    %{uuid: fee_rules_uuid} = fee_rules = insert(:fee_rules, params)
    catch_error(Update.fees(fee_rules_uuid, fee_rules.data))
  end
end
