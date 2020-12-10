defmodule Engine.DB.ContractsConfigTest do
  use Engine.DB.DataCase, async: false

  alias Engine.DB.ContractsConfig

  @params %{
    eth_vault: "eth_from_db",
    erc20_vault: "erc_from_db",
    payment_exit_game: "payment_exit_game",
    min_exit_period_seconds: 20,
    contract_semver: "2.0.0+ddbd40b",
    child_block_interval: 1000,
    contract_deployment_height: 120
  }

  describe "get/1" do
    test "does not return irrelevant data" do
      {:ok, _} = ContractsConfig.insert(Repo, @params)

      actual = ContractsConfig.get(Repo)
      expected = Keyword.new(@params)
      assert actual == expected
    end
  end

  describe "insert/2" do
    test "fails when there is a config in the database" do
      {:ok, _} = ContractsConfig.insert(Repo, @params)

      assert_raise Ecto.ConstraintError, ~r/contracts_config_guard_index/, fn ->
        ContractsConfig.insert(Repo, @params)
      end
    end
  end
end
