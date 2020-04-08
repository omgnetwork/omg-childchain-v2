defmodule Engine.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Engine.Repo

  def deposit_transaction_factory(attrs) do
    %{blknum: blknum} = attrs

    %Engine.Transaction{
      tx_type: 1,
      tx_data: 0,
      metadata: <<0::160>>,
      inputs: [],
      outputs:
        build(:output_utxo, %{
          blknum: blknum || :rand.uniform(100) + 1,
          txindex: 0,
          oindex: 0
        })
    }
  end

  def deposit_block_factory() do
    # NB: Hax to ensure we don't use whole numbers, which are
    # the non-deposit blocks
    blknum = :rand.uniform(100) + 1

    %Engine.Block{
      number: blknum,
      transactions:
        build(:deposit_transaction, %{
          blknum: blknum
        })
    }
  end

  def transaction_factory() do
    %Engine.Transaction{
      tx_type: 1,
      tx_data: 0,
      metadata: <<0::160>>,
      inputs: [build(:input_utxo)],
      outputs: [build(:output_utxo)]
    }
  end

  def input_utxo_factory() do
    blknum = :rand.uniform(100)

    %Engine.Utxo{
      blknum: blknum,
      txindex: 0,
      oindex: 0,
      owner: <<1::160>>,
      currency: <<0::160>>,
      amount: :rand.uniform(100)
    }
  end

  def spent_utxo_factory() do
    %Engine.Utxo{
      blknum: :rand.uniform(100),
      txindex: 0,
      oindex: 0,
      owner: <<1::160>>,
      currency: <<0::160>>,
      amount: :random.uniform(100),
      spending_transaction: build(:transaction)
    }
  end

  def output_utxo_factory() do
    %Engine.Utxo{
      owner: <<1::160>>,
      currency: <<0::160>>,
      amount: :rand.uniform(100)
    }
  end
end
