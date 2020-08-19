defmodule API.V1.FeesTest do
  use ExUnit.Case, async: true

  alias API.V1.Fees
  alias Engine.DB.Fee, as: DbFees

  setup_all do
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

  describe "all/1" do
    test "filters the result when given currencies" do
      assert %{
               "1" => [
                 %{
                   amount: 1,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ],
               "2" => [
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ]
             } = Fees.all(%Plug.Conn{params: %{"currencies" => ["0x0000000000000000000000000000000000000000"]}})
    end

    test "fees.all endpoint does not filter when given empty currencies" do
      assert %{
               "1" => [
                 %{
                   amount: 1,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 },
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000001",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ],
               "2" => [
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ]
             } = Fees.all(%Plug.Conn{params: %{"currencies" => []}})
    end

    test "fees.all endpoint does not filter without an empty body" do
      assert %{
               "1" => [
                 %{
                   amount: 1,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 },
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000001",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ],
               "2" => [
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ]
             } = Fees.all(%Plug.Conn{params: %{}})
    end

    test "fees.all returns an error when given unsupported currency" do
      assert %{
               code: "fee:currency_fee_not_supported",
               description: "One or more of the given currencies are not supported as a fee-token.",
               object: :error
             } = Fees.all(%Plug.Conn{params: %{"currencies" => ["0x0000000000000000000000000000000000000005"]}})
    end

    test "fees.all endpoint rejects request with non list currencies" do
      assert %{
               code: "operation:bad_request",
               description: "Parameters required by this operation are missing or incorrect.",
               messages: %{validation_error: %{parameter: "currencies", validator: ":list"}},
               object: :error
             } = Fees.all(%Plug.Conn{params: %{"currencies" => "0x0000000000000000000000000000000000000000"}})
    end

    test "fees.all endpoint rejects request with non hex currencies" do
      assert %{
               code: "operation:bad_request",
               description: "Parameters required by this operation are missing or incorrect.",
               messages: %{validation_error: %{parameter: "currencies.currency", validator: ":hex"}},
               object: :error
             } = Fees.all(%Plug.Conn{params: %{"currencies" => ["invalid"]}})
    end

    test "fees.all endpoint filters the result when given tx_types" do
      assert %{
               "1" => [
                 %{
                   amount: 1,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 },
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000001",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ]
             } = Fees.all(%Plug.Conn{params: %{"tx_types" => [1]}})
    end

    test "fees.all endpoint does not filter when given empty tx_types" do
      assert %{
               "1" => [
                 %{
                   amount: 1,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 },
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000001",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ],
               "2" => [
                 %{
                   amount: 2,
                   currency: "0x0000000000000000000000000000000000000000",
                   pegged_amount: 1,
                   pegged_currency: "USD",
                   pegged_subunit_to_unit: 100,
                   subunit_to_unit: 1_000_000_000_000_000_000,
                   updated_at: ~U[2019-01-01 10:00:00Z]
                 }
               ]
             } = Fees.all(%Plug.Conn{params: %{"tx_types" => []}})
    end

    test "fees.all returns an error when given unsupported tx_types" do
      assert %{
               code: "fee:tx_type_not_supported",
               description: "One or more of the given transaction types are not supported.",
               object: :error
             } = Fees.all(%Plug.Conn{params: %{"tx_types" => [99_999]}})
    end

    test "fees.all endpoint rejects request with non list tx_types" do
      assert %{
               code: "operation:bad_request",
               description: "Parameters required by this operation are missing or incorrect.",
               messages: %{validation_error: %{parameter: "tx_types", validator: ":list"}},
               object: :error
             } = Fees.all(%Plug.Conn{params: %{"tx_types" => 1}})
    end

    test "fees.all endpoint rejects request with negative integer" do
      assert %{
               code: "operation:bad_request",
               description: "Parameters required by this operation are missing or incorrect.",
               messages: %{validation_error: %{parameter: "tx_types.tx_type", validator: "{:greater, -1}"}},
               object: :error
             } = Fees.all(%Plug.Conn{params: %{"tx_types" => [-5]}})
    end
  end
end
