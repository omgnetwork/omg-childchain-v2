defmodule Engine.DB.BlockTest do
  use Engine.DB.DataCase, async: true
  doctest Engine.DB.Block, import: true

  import Ecto.Query, only: [from: 2]

  alias Engine.DB.Block
  alias ExPlasma.Merkle

  setup do
    _ = insert(:fee, type: :merged_fees)

    :ok
  end
end
