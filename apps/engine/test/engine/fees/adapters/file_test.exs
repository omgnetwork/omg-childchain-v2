defmodule Engine.Fees.Adapters.FileTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Engine.Fees.Adapters.File, as: FileAdapter
  alias ExPlasma.Encoding

  doctest FileAdapter

  @eth <<0::160>>
  @eth_hex Encoding.to_hex(@eth)
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
      }
    }
  }

  @stored_fees_empty %{}

  describe "get_fee_specs/1" do
    test "returns the fee specs if recorded_file_updated_at is older than
          actual_file_updated_at" do
      recorded_file_updated_at = :os.system_time(:second) - 10

      {:ok, file_path} = write_file(@fees)
      {:ok, %File.Stat{mtime: mtime}} = File.stat(file_path, time: :posix)
      opts = [specs_file_path: file_path]

      assert FileAdapter.get_fee_specs(opts, @stored_fees_empty, recorded_file_updated_at) == {
               :ok,
               %{@payment_tx_type => %{@eth => @fees[1][@eth_hex]}},
               mtime
             }

      File.rm(file_path)
    end

    test "returns :ok (unchanged) if file_updated_at is more recent
          than file last change timestamp" do
      {:ok, file_path} = write_file(@fees)
      opts = [specs_file_path: file_path]
      recorded_file_updated_at = :os.system_time(:second) + 10

      assert FileAdapter.get_fee_specs(opts, @stored_fees_empty, recorded_file_updated_at) == :ok
      File.rm(file_path)
    end

    test "returns an error if the file is not found" do
      opts = [specs_file_path: "fake_path/fake_fee_file.json"]
      assert FileAdapter.get_fee_specs(opts, @stored_fees_empty, 1) == {:error, :enoent}
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
