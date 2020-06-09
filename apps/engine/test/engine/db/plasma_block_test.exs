defmodule Engine.DB.PlasmaBlockTest do
  use Engine.DB.DataCase, async: true
  alias Engine.DB.PlasmaBlock

  test "does factory work or what" do
    IO.inspect(insert(:plasma_block))
    submission = fn data -> IO.inspect(data) end
    IO.inspect(PlasmaBlock.get_all_and_submit(2, 2000, submission))
  end
end
