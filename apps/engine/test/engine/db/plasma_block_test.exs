defmodule Engine.DB.PlasmaBlockTest do
  use Engine.DB.DataCase, async: true
  alias Engine.DB.PlasmaBlock
  import Ecto.Query, only: [from: 2]

  test "does factory work or what" do
    insert(:plasma_block)

    submission = fn data ->
      IO.inspect(data, label: "vault call")
      :ol
    end

    PlasmaBlock.get_all_and_submit(3, 2000, submission)

    Process.sleep(1000)
    query = from(p in PlasmaBlock, where: p.submitted_at_ethereum_height < 4 and p.blknum < 3000)
    IO.inspect({:ok, Engine.Repo.all(query)}, label: "koncno jebote pas ketno mater")
  end
end
