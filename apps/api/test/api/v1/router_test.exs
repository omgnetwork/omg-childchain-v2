defmodule API.V1.RouterTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.V1.Router
  alias ExPlasma.Encoding

  test "sets the api version" do
    conn =
      :post
      |> conn("/")
      |> Router.call(Router.init([]))

    assert conn.assigns[:api_version] == "1.0"
  end

  setup_all do
    fee_specs = %{
      1 => %{
        Base.decode16!("0000000000000000000000000000000000000000") => %{
          amount: 1,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 10,
          updated_at: DateTime.from_unix!(1_546_336_800)
        },
        Base.decode16!("0000000000000000000000000000000000000001") => %{
          amount: 2,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 10,
          updated_at: DateTime.from_unix!(1_546_336_800)
        }
      },
      2 => %{
        Base.decode16!("0000000000000000000000000000000000000000") => %{
          amount: 2,
          subunit_to_unit: 1_000_000_000_000_000_000,
          pegged_amount: 1,
          pegged_currency: "USD",
          pegged_subunit_to_unit: 10,
          updated_at: DateTime.from_unix!(1_546_336_800)
        }
      }
    }

    params = [
      term: fee_specs,
      type: :current_fees,
      hash:
        :sha256
        |> :crypto.hash(inspect(fee_specs))
        |> Base.encode16(case: :lower),
      inserted_at: DateTime.add(DateTime.utc_now(), 10_000_000, :second)
    ]

    _ = insert(:fee, params)

    %{
      expected_result: %{
        "1" => [
          %{
            "amount" => 1,
            "currency" => "0x0000000000000000000000000000000000000000",
            "pegged_amount" => 1,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 10,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "updated_at" => "2019-01-01T10:00:00Z"
          },
          %{
            "amount" => 2,
            "currency" => "0x0000000000000000000000000000000000000001",
            "pegged_amount" => 1,
            "pegged_currency" => "USD",
            "pegged_subunit_to_unit" => 10,
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
            "pegged_subunit_to_unit" => 10,
            "subunit_to_unit" => 1_000_000_000_000_000_000,
            "updated_at" => "2019-01-01T10:00:00Z"
          }
        ]
      }
    }
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
    test "that it returns a block" do
      transaction = insert(:deposit_transaction)
      tx_bytes = Encoding.to_hex(transaction.tx_bytes)
      hash = Encoding.to_hex(transaction.block.hash)
      number = transaction.block.number
      {:ok, payload} = post("block.get", %{hash: hash})

      assert_payload_data(payload, %{
        "blknum" => number,
        "hash" => hash,
        "transactions" => [tx_bytes],
        "object" => "block"
      })
    end

    test "that it returns an error if missing hash params" do
      {:ok, payload} = post("block.get", %{})

      assert_payload_data(payload, %{
        "code" => "missing_required_param",
        "description" => "missing required key 'hash'",
        "object" => "error"
      })
    end

    test "that it returns an error if hash param is not a hex" do
      {:ok, payload} = post("block.get", %{hash: "12345"})

      assert_payload_data(payload, %{
        "code" => "invalid_param_type",
        "description" => "hex values must be prefixed with 0x, got: '12345'",
        "object" => "error"
      })
    end
  end

  describe "transaction.submit" do
    test "decodes a transaction and inserts it" do
      _ = insert(:deposit_transaction)
      txn = build(:payment_v1_transaction)
      tx_bytes = Encoding.to_hex(txn.tx_bytes)
      tx_hash = Encoding.to_hex(txn.tx_hash)
      {:ok, payload} = post("transaction.submit", %{transaction: tx_bytes})

      assert_payload_data(payload, %{"tx_hash" => tx_hash, "object" => "transaction"})
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
    assert payload["service_name"] == "childchain"
    assert payload["version"] == "1.0"
    assert payload["data"] == data
  end
end
