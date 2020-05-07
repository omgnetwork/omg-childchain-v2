defmodule Engine.Feefeed.Rules.WorkerTest do
  use Engine.DB.DataCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Ecto.Adapters.SQL.Sandbox
  alias Engine.DB.FeeRules
  alias Engine.DB.Fees
  alias Engine.Feefeed.Rules.Worker
  alias ExVCR.Config

  setup do
    Config.cassette_library_dir("test/support/vcr_cassettes")
    :ok
  end

  describe "update/2 with valid source" do
    setup %{test: test_name} do
      start_worker_with_source(test_name, "omisego")
    end

    test "updates the rules if changed", %{test: test_name} do
      use_cassette "fetch_fee_rules_success" do
        assert FeeRules.fetch_latest() == {:error, :not_found}

        Worker.update(test_name)
        %{} = :sys.get_state(test_name)

        assert {:ok, %{data: %{}, uuid: uuid}} = FeeRules.fetch_latest()
        {:ok, fees} = Fees.fetch_latest()
        assert fees.fee_rules_uuid == uuid
      end
    end

    test "does nothing if rules didn't change", %{test: test_name} do
      %{data: existing_data} = insert(:fee_rules)

      use_cassette "fetch_fee_rules_success" do
        {:ok, %{data: current_data} = rules} = FeeRules.fetch_latest()
        assert current_data == existing_data

        Worker.update(test_name)

        assert FeeRules.fetch_latest() == {:ok, rules}
      end
    end
  end

  describe "update/2 with invalid source" do
    setup %{test: test_name} do
      start_worker_with_source(test_name, "nomisego")
    end

    test "does not update rules if rules retrieval failed and logs", %{test: test_name} do
      worker_pid = Process.whereis(test_name)

      use_cassette "fetch_fee_rules_404" do
        assert FeeRules.fetch_latest() == {:error, :not_found}
        Process.flag(:trap_exit, true)

        Worker.update(worker_pid)
        catch_exit(:sys.get_state(worker_pid))

        assert_received({:EXIT, ^worker_pid, {{:badmatch, {:error, :response, 404, _}}, _}})
      end
    end
  end

  defp start_worker_with_source(test_name, org) do
    config = %{
      token: "abc",
      org: org,
      repo: "fee-rules",
      branch: "test",
      filename: "fee_rules"
    }

    {:ok, pid} = Worker.start_link(name: test_name, config: config)
    Sandbox.allow(Repo, self(), pid)
  end
end
