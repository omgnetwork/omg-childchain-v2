defmodule API.V1.RouterTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.V1.Router
  alias Engine.DB.Fee, as: DbFees
  alias ExPlasma.Encoding

  test "sets the api version" do
    conn =
      :post
      |> conn("/")
      |> Router.call(Router.init([]))

    assert conn.assigns[:api_version] == "1.0"
  end

  describe "fees.all" do
    setup do
      fee_specs = %{
        1 => %{
          Base.decode16!("0000000000000000000000000000000000000000") => %{
            amount: 1,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_amount: 1,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.from_unix!(1_546_336_800)
          },
          Base.decode16!("0000000000000000000000000000000000000001") => %{
            amount: 2,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_amount: 1,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.from_unix!(1_546_336_800)
          }
        },
        2 => %{
          Base.decode16!("0000000000000000000000000000000000000000") => %{
            amount: 2,
            subunit_to_unit: 1_000_000_000_000_000_000,
            pegged_amount: 1,
            pegged_currency: "USD",
            pegged_subunit_to_unit: 100,
            updated_at: DateTime.from_unix!(1_546_336_800)
          }
        }
      }

      params = %{term: fee_specs, type: "current_fees"}

      {:ok, _fees} = DbFees.insert(params)

      %{}
    end

    test "fees.all endpoint does not filter when given empty currencies" do
      {:ok, payload} = post("fees.all", %{})

      assert_payload_data(payload, %{
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

  def post(endpoint, data) do
    :post
    |> conn(endpoint, Jason.encode!(data))
    |> put_req_header("content-type", "application/json")
    |> Router.call(Router.init([]))
    |> Map.get(:resp_body)
    |> Jason.decode()
  end

  def assert_payload_data(payload, data) do
    assert payload["service_name"] == "childchain"
    assert payload["version"] == "1.0"
    assert payload["data"] == data
  end
end
