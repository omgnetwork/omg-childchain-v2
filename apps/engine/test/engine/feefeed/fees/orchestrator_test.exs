defmodule Engine.Feefeed.Fees.OrchestratorTest do
  # use Feefeed.GenServerCase, async: true

  import ExUnit.CaptureLog

  alias Ecto.UUID

  alias Engine.Feefeed.Fees.Orchestrator
  alias Engine.Feefeed.DB.Fees

  # describe "start_link/1" do
  #   test "starts the genserver" do
  #     {:ok, pid} = Orchestrator.start_link(name: OrchestratorT)

  #     assert Process.alive?(pid)
  #     GenServer.stop(pid)
  #   end
  # end

  # describe "compute_fees/2" do
  #   setup do
  #     start_test_orchestrator()
  #   end

  #   test "updates the fees if changed", %{orchestrator_pid: orchestrator_pid} do
  #     assert Fees.fetch_latest() == {:error, :not_found}

  #     %{uuid: rules_uuid} = insert(:fee_rules)

  #     Orchestrator.compute_fees(orchestrator_pid, rules_uuid)

  #     assert :sys.get_state(orchestrator_pid) == %{}

  #     assert {:ok, %{data: %{}, uuid: _, fee_rules_uuid: rules_uuid}} = Fees.fetch_latest()
  #   end

  #   test "does nothing if fees didn't change", %{orchestrator_pid: orchestrator_pid} do
  #     %{uuid: rules_uuid} = insert(:fee_rules)

  #     Orchestrator.compute_fees(orchestrator_pid, rules_uuid)
  #     assert :sys.get_state(orchestrator_pid) == %{}

  #     assert {:ok, fees} = Fees.fetch_latest()

  #     Orchestrator.compute_fees(orchestrator_pid, rules_uuid)
  #     assert :sys.get_state(orchestrator_pid) == %{}

  #     assert Fees.fetch_latest() == {:ok, fees}
  #   end

  #   test "recovers by retrying fetching the rules when not present", %{
  #     orchestrator_pid: orchestrator_pid
  #   } do
  #     rules_uuid = UUID.generate()
  #     retry_interval = Application.get_env(:feefeed, :db_fetch_retry_interval)

  #     # We start with a clean state
  #     assert Fees.fetch_latest() == {:error, :not_found}

  #     # The rule is not yet inserted, the orchestrator will try to query it
  #     # up to 3 times every `retry_interval`
  #     func = fn ->
  #       Orchestrator.compute_fees(orchestrator_pid, rules_uuid)

  #       # We sleep for retry_interval to simulate a late DB propagation
  #       Process.sleep(retry_interval)

  #       # We insert a rule with the same uuid that we provided to the orchestrator
  #       _rules = insert(:fee_rules, %{uuid: rules_uuid})

  #       assert :sys.get_state(orchestrator_pid) == %{}
  #       assert {:ok, %{fee_rules_uuid: rules_uuid}} = Fees.fetch_latest()
  #     end

  #     assert capture_log(func) =~
  #              "Warning: Fee rule with uuid: #{rules_uuid} not found in DB, retrying in #{
  #                retry_interval
  #              } ms. Current rety count: 0"
  #   end

  #   test "crashes the server if the rule uuid is not the latest", %{
  #     orchestrator_pid: orchestrator_pid
  #   } do
  #     %{uuid: rules_uuid} = insert(:fee_rules)
  #     _ = insert(:fee_rules)

  #     Process.flag(:trap_exit, true)

  #     assert capture_log(fn ->
  #              Orchestrator.compute_fees(orchestrator_pid, rules_uuid)

  #              catch_exit(:sys.get_state(orchestrator_pid))

  #              assert_received(
  #                {:EXIT, ^orchestrator_pid, {{:badmatch, {:error, :not_found, _}}, _}}
  #              )
  #            end) =~ "does not match the given uuid"
  #   end

  #   test "crashes the server if the rule is invalid", %{orchestrator_pid: orchestrator_pid} do
  #     params =
  #       :fee_rules
  #       |> params_for()
  #       |> Kernel.put_in(
  #         [:data, "1", "0x0000000000000000000000000000000000000000", "type"],
  #         "invalid"
  #       )

  #     %{uuid: rules_uuid} = insert(:fee_rules, params)

  #     Process.flag(:trap_exit, true)

  #     assert capture_log(fn ->
  #              Orchestrator.compute_fees(orchestrator_pid, rules_uuid)

  #              catch_exit(:sys.get_state(orchestrator_pid))

  #              assert_received(
  #                {:EXIT, ^orchestrator_pid, {{:badmatch, {:error, :unsupported_fee_type, _}}, _}}
  #              )
  #            end) =~ "got: 'invalid', which is not currently supported"
  #   end
  # end
end
