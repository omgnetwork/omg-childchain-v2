defmodule API.V1.RouterTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test
  import ExPlasma.Encoding, only: [to_hex: 1]

  alias API.Plugs.ExpectParams.InvalidParams
  alias API.V1.Router

  describe "/block.get" do
    test "that it returns a block" do
      transaction = insert(:deposit_transaction)
      tx_bytes = to_hex(transaction.tx_bytes)
      hash = to_hex(transaction.block.hash)
      number = transaction.block.number
      {:ok, payload} = post("/block.get", %{hash: hash})

      assert_payload_data(payload, %{"blknum" => number, "hash" => hash, "transactions" => [tx_bytes]})
    end

    test "that it returns an error if missing hash params" do
      req = conn(:post, "/block.get", "{}")

      assert_raise(InvalidParams, fn -> Router.call(req, Router.init([])) end)
      assert {400, _header, body} = sent_resp(req)

      payload = Jason.decode!(body)

      assert_payload_data(payload, %{"error" => "missing required key \"hash\""})
    end

    test "that it returns an error if hash param is not a hex" do
      req =
        :post
        |> conn("/block.get", Jason.encode!(%{hash: "12345"}))
        |> put_req_header("content-type", "application/json")

      assert_raise(InvalidParams, fn -> Router.call(req, Router.init([])) end)
      assert {400, _header, body} = sent_resp(req)

      payload = Jason.decode!(body)

      assert_payload_data(payload, %{"error" => "hash must be prefixed with \"0x\""})
    end
  end

  describe "/transaction.submit" do
    test "decodes a transaction and inserts it" do
      _ = insert(:deposit_transaction)
      txn = build(:payment_v1_transaction)
      tx_bytes = ExPlasma.Encoding.to_hex(txn.tx_bytes)
      tx_hash = ExPlasma.Encoding.to_hex(txn.tx_hash)
      {:ok, payload} = post("/transaction.submit", %{transaction: tx_bytes})

      assert_payload_data(payload, %{"tx_hash" => tx_hash})
    end

    test "that it returns an error if missing transaction params" do
      req = conn(:post, "/transaction.submit", "{}")

      assert_raise(InvalidParams, fn -> Router.call(req, Router.init([])) end)
      assert {400, _header, body} = sent_resp(req)

      payload = Jason.decode!(body)

      assert_payload_data(payload, %{"error" => "missing required key \"transaction\""})
    end

    test "that it returns an error if transaction param is not a hex" do
      req =
        :post
        |> conn("/transaction.submit", Jason.encode!(%{transaction: "12345"}))
        |> put_req_header("content-type", "application/json")

      assert_raise(InvalidParams, fn -> Router.call(req, Router.init([])) end)
      assert {400, _header, body} = sent_resp(req)

      payload = Jason.decode!(body)

      assert_payload_data(payload, %{"error" => "transaction must be prefixed with \"0x\""})
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
