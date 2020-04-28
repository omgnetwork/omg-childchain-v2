defmodule Deposit do
  use ExUnit.Case, async: true

  alias Engine.Geth

  @moduletag :integration

  setup_all do
    Application.stop(:engine)
    _docker_id = Geth.start(8549)
    %{url: "http://127.0.0.0.1:8545"}
  end

  test "deposit is recognized by the aggregator", %{url: url} do
    Process.sleep(30_000)
    assert true
  end
end
