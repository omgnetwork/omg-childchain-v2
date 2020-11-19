defmodule API.V1.RouterTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.V1.Router
  alias Engine.DB.Block
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Encoding

  setup do
    _ = insert(:current_fee)

    %{
      expected_result: %{
        "1" => [
          %{
            "amount" => 1,
            "currency" => "0x0000000000000000000000000000000000000000",
            "pegged_amount" => 1,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "updated_at" => "2019-01-01T10:00:00Z"
          },
          %{
            "amount" => 2,
            "currency" => "0x0000000000000000000000000000000000000001",
            "pegged_amount" => 1,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "updated_at" => "2019-01-01T10:00:00Z"
          }
        ],
        "2" => [
          %{
            "amount" => 2,
            "currency" => "0x0000000000000000000000000000000000000000",
            "pegged_amount" => 1,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 100,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "updated_at" => "2019-01-01T10:00:00Z"
          }
        ]
      }
    }
  end

  test "sets the api version" do
    conn =
      :post
      |> conn("/")
      |> Router.call(Router.init([]))

    assert conn.assigns[:api_version] == "1.0"
  end

  describe "fees.all" do
    test "fees.all endpoint does not filter without an empty body", %{expected_result: expected_result} do
      {:ok, payload} = post("fees.all", %{})

      assert_payload_data(payload, expected_result)
    end

    test "filters the result when given currencies", %{expected_result: %{"1" => [first | _], "2" => all}} do
      {:ok, payload} = post("fees.all", %{"currencies" => ["0x0000000000000000000000000000000000000000"]})

      assert_payload_data(payload, %{"1" => [first], "2" => all})
    end

    test "fees.all endpoint does not filter when given empty currencies", %{expected_result: expected_result} do
      {:ok, payload} = post("fees.all", %{"currencies" => []})

      assert_payload_data(payload, expected_result)
    end

    test "fees.all endpoint filters the result when given tx_types", %{expected_result: %{"1" => expected_result}} do
      {:ok, payload} = post("fees.all", %{"tx_types" => [1]})

      assert_payload_data(payload, %{"1" => expected_result})
    end

    test "fees.all endpoint does not filter when given empty tx_types", %{expected_result: expected_result} do
      {:ok, payload} = post("fees.all", %{"tx_types" => []})

      assert_payload_data(payload, expected_result)
    end

    test "fees.all returns an error when given unsupported currency" do
      {:ok, payload} = post("fees.all", %{"currencies" => ["0x0000000000000000000000000000000000000005"]})

      assert_payload_data(payload, %{
        "code" => "currency_fee_not_supported",
        "description" => "One or more of the given currencies are not supported as a fee-token",
        "object" => "error"
      })
    end

    test "fees.all endpoint rejects request with non list currencies" do
      {:ok, payload} = post("fees.all", %{"currencies" => "0x0000000000000000000000000000000000000005"})

      assert_payload_data(payload, %{
        "code" => "invalid_param_type",
        "description" => "provided value is not a list, got: '0x0000000000000000000000000000000000000005'",
        "object" => "error"
      })
    end

    test "fees.all returns an error when given unsupported tx_types" do
      {:ok, payload} = post("fees.all", %{"tx_types" => [99_999]})

      assert_payload_data(payload, %{
        "code" => "tx_type_not_supported",
        "description" => "One or more of the given transaction types are not supported",
        "object" => "error"
      })
    end
  end

  describe "block.get" do
    setup do
      block = insert(:block)
      {:ok, %{forming_block: block}}
    end

    test "it returns a block", %{forming_block: block} do
      transaction = insert(:payment_v1_transaction, %{block: block})

      :ok = Block.finalize_forming_block()
      {:ok, %{blocks_for_submission: [formed_block]}} = Block.prepare_for_submission()

      tx_bytes = Encoding.to_hex(transaction.tx_bytes)
      hash = Encoding.to_hex(formed_block.hash)
      number = formed_block.blknum
      {:ok, payload} = post("block.get", %{hash: hash})

      assert_payload_data(payload, %{
        "blknum" => number,
        "hash" => hash,
        "transactions" => [tx_bytes]
      })
    end

    test "it returns an error if missing hash params" do
      {:ok, payload} = post("block.get", %{})

      assert_payload_data(payload, %{
        "code" => "missing_required_param",
        "description" => "missing required key 'hash'",
        "object" => "error"
      })
    end

    test "it returns an error if hash param is not a hex" do
      {:ok, payload} = post("block.get", %{hash: "12345"})

      assert_payload_data(payload, %{
        "code" => "invalid_param_type",
        "description" => "hex values must be prefixed with 0x, got: '12345'",
        "object" => "error"
      })
    end
  end

  describe "transaction.submit" do
    setup do
      block = insert(:block)
      {:ok, %{blknum: block.blknum}}
    end

    test "after a block is formed, incoming transaction is associated with a new block", %{blknum: blknum} do
      insert(:merged_fee)

      {tx_bytes1, tx_hash1} = tx_bytes_and_hash()

      {:ok, payload1} = post("transaction.submit", %{transaction: Encoding.to_hex(tx_bytes1)})

      assert_payload_data(payload1, %{"tx_hash" => Encoding.to_hex(tx_hash1), "blknum" => blknum, "tx_index" => 0})

      {tx_bytes2, tx_hash2} = tx_bytes_and_hash()

      {:ok, payload2} = post("transaction.submit", %{transaction: Encoding.to_hex(tx_bytes2)})

      assert_payload_data(payload2, %{"tx_hash" => Encoding.to_hex(tx_hash2), "blknum" => blknum, "tx_index" => 1})

      _ = Block.finalize_forming_block()
      next_blknum = blknum + 1_000

      {tx_bytes3, tx_hash3} = tx_bytes_and_hash()

      {:ok, payload3} = post("transaction.submit", %{transaction: Encoding.to_hex(tx_bytes3)})

      assert_payload_data(payload3, %{"tx_hash" => Encoding.to_hex(tx_hash3), "blknum" => next_blknum, "tx_index" => 0})
    end

    test "that it returns an error if missing transaction params" do
      {:ok, payload} = post("transaction.submit", %{})

      assert_payload_data(payload, %{
        "code" => "missing_required_param",
        "description" => "missing required key 'transaction'",
        "object" => "error"
      })
    end

    test "that it returns an error if transaction param is not a hex" do
      {:ok, payload} = post("transaction.submit", %{transaction: "12345"})

      assert_payload_data(payload, %{
        "code" => "invalid_param_type",
        "description" => "hex values must be prefixed with 0x, got: '12345'",
        "object" => "error"
      })
    end
  end

  defp post(endpoint, data) do
    :post
    |> conn(endpoint, Jason.encode!(data))
    |> put_req_header("content-type", "application/json")
    |> Router.call(Router.init([]))
    |> Map.get(:resp_body)
    |> Jason.decode()
  end

  defp assert_payload_data(payload, data) do
    assert payload["service_name"] == "child_chain"
    assert payload["version"] == "1.0"
    assert payload["data"] == data
  end

  defp tx_bytes_and_hash() do
    entity = TestEntity.alice()

    %{output_id: input_output_id} = insert(:deposit_output, amount: 10, output_guard: entity.addr)
    %{output_data: output_data} = build(:output, output_guard: entity.addr, amount: 9)

    transaction =
      Builder.new(ExPlasma.payment_v1(), %{
        inputs: [ExPlasma.Output.decode_id!(input_output_id)],
        outputs: [ExPlasma.Output.decode!(output_data)]
      })

    tx_bytes =
      transaction
      |> Builder.sign!([entity.priv_encoded])
      |> ExPlasma.encode!()

    {:ok, tx_hash} = ExPlasma.Transaction.hash(transaction)

    {tx_bytes, tx_hash}
  end
end
