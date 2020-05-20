defmodule API.V1.RouterTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias API.V1.Router
  alias Engine.DB.Block

  describe "/block.get" do
    test "that it returns a block" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()
      hash = ExPlasma.Encoding.to_hex(block.hash)

      {:ok, payload} = post("/block.get", %{hash: hash})

      assert payload["service_name"] == "childchain"
      assert payload["version"] == "1.0"

      assert payload["data"] == %{
               "blknum" => nil,
               "hash" => "0x39662d06a769f21f750ee5a2bdc3cdad2dfffc182c77ce9d194215f4b8f3455b",
               "transactions" => [
                 "0xf87401e1a0000000000000000000000000000000000000000000000000000000003b9aca00eeed01eb9400000000000000000000000000000000000000019400000000000000000000000000000000000000000180a00000000000000000000000000000000000000000000000000000000000000000"
               ]
             }
    end

    test "that it returns an error if missing hash params" do
      {:ok, payload} = post("/block.get", %{})

      assert payload["service_name"] == "childchain"
      assert payload["version"] == "1.0"

      assert payload["data"] == %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "hash"
                 }
               }
             }
    end
  end

  describe "/transaction.submit" do
    test "decodes a transaction and inserts it" do
      _ = insert(:deposit_transaction)
      txn = build(:payment_v1_transaction)
      tx_bytes = ExPlasma.Encoding.to_hex(txn.tx_bytes)

      {:ok, payload} = post("/transaction.submit", %{transaction: tx_bytes})

      assert payload["service_name"] == "childchain"
      assert payload["version"] == "1.0"

      assert payload["data"] == %{
               "tx_hash" => "0xead85979109fb81530392a4cca36cb7b112fb49739c7844e0bafbe9e247ce773"
             }
    end

    test "that it returns an error if missing params" do
      {:ok, payload} = post("/transaction.submit", %{})

      assert payload["service_name"] == "childchain"
      assert payload["version"] == "1.0"

      assert payload["data"] == %{
               "object" => "error",
               "code" => "operation:bad_request",
               "messages" => %{
                 "validation_error" => %{
                   "parameter" => "transaction"
                 }
               }
             }
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
end
