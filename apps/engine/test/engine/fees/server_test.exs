defmodule Engine.Fees.ServerTest do
  use ExUnit.Case

  alias Engine.Configuration
  alias Engine.Fees.Adapters.File, as: FileAdapter
  alias Engine.Fees.Server
  alias ExPlasma.Encoding

  @eth <<0::160>>
  @eth_hex Encoding.to_hex(@eth)
  @not_eth <<1::160>>
  @not_eth_hex Encoding.to_hex(@not_eth)
  @payment_tx_type Encoding.to_int(ExPlasma.payment_v1())

  @fees %{
    @payment_tx_type => %{
      @eth_hex => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      },
      @not_eth_hex => %{
        amount: 2,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    },
    2 => %{
      @eth_hex => %{
        amount: 1,
        pegged_amount: 1,
        subunit_to_unit: 1_000_000_000_000_000_000,
        pegged_currency: "USD",
        pegged_subunit_to_unit: 100,
        updated_at: DateTime.from_unix!(1_546_336_800)
      }
    }
  }

  setup %{test: name} do
    {:ok, path} = write_file(@fees)
    fee_server_opts = Configuration.fee_server_opts()

    Keyword.merge(
      fee_server_opts,
      fee_adapter: FileAdapter,
      fee_adapter_opts: [specs_file_path: path],
      name: name
    )

    {:ok, _} = start_supervised({Server, fee_server_opts})
    :ok
  end

  describe "update_fee_specs/1" do
    test "faulty fees don't crash" do
    end
  end

  defp write_file(data) do
    {:ok, path} = Briefly.create()

    {:ok, json} =
      data
      |> Enum.map(fn {tx_type, fees} ->
        {Integer.to_string(tx_type), parse_fees(fees)}
      end)
      |> Enum.into(%{})
      |> Jason.encode()

    File.write!(path, json)
    {:ok, path}
  end

  defp parse_fees(fees) do
    Enum.map(fees, fn {"0x" <> _ = token, fee} ->
      %{
        token: token,
        amount: fee.amount,
        subunit_to_unit: fee.subunit_to_unit,
        pegged_amount: fee.pegged_amount,
        pegged_currency: fee.pegged_currency,
        pegged_subunit_to_unit: fee.pegged_subunit_to_unit,
        updated_at: fee.updated_at
      }
    end)
  end
end
