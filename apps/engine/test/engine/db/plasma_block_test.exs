defmodule Engine.DB.PlasmaBlockTest do
  use Engine.DB.DataCase, async: true
  alias Engine.DB.PlasmaBlock
  import Ecto.Query, only: [from: 2]

  test "does factory work or what" do
    insert(:plasma_block)

    submission = fn _data ->
      :ok
    end

    PlasmaBlock.get_all_and_submit(3, 2000, submission)

    Process.sleep(1000)
    query = from(p in PlasmaBlock, where: p.submitted_at_ethereum_height < 4 and p.blknum < 3000)
    assert query |> Engine.Repo.all() |> hd |> Map.get(:gas) == 828
  end
end
