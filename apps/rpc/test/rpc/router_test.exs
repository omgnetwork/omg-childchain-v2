defmodule RPC.RouterTest do
  use Engine.DB.DataCase, async: true
  use Plug.Test

  alias Engine.DB.Block

  describe "/block.get" do
    test "that it returns a block" do
      _ = insert(:deposit_transaction)
      _ = insert(:payment_v1_transaction)
      {:ok, %{"hash-block" => block}} = Block.form()
      hash = ExPlasma.Encoding.to_hex(block.hash)

      req =
        :post
        |> conn("/block.get", Jason.encode!(%{hash: hash}))
        |> put_req_header("content-type", "application/json")
        |> RPC.Router.call(RPC.Router.init([]))

      {:ok, payload} = Jason.decode(req.resp_body)

      assert payload["service_name"] == "childchain"
      assert payload["version"] == "1.0"
      assert payload["data"] == %{ 
        "blknum" => nil,
        "hash" => "0x39662d06a769f21f750ee5a2bdc3cdad2dfffc182c77ce9d194215f4b8f3455b",
        "transactions" => ["0xf87401e1a0000000000000000000000000000000000000000000000000000000003b9aca00eeed01eb9400000000000000000000000000000000000000019400000000000000000000000000000000000000000180a00000000000000000000000000000000000000000000000000000000000000000"]
      }
    end
  end

  describe "/transaction.submit" do
  end
end
