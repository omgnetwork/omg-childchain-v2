defmodule Engine.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: Engine.Repo

  alias Engine.DB.Transaction2, as: Transaction
  alias Engine.DB.Output

  # This feels meh. Need to figure out how we want to handle
  # creating transactions "from scratch" and how we
  # do transaction encoding the other way (childchain consumes txbytes)
  def deposit_factory(%{amount: amount}) do
    output_data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: amount}
    output = %ExPlasma.Output{output_type: 1, output_data: output_data}
    txn = %ExPlasma.Transaction{tx_type: 1, outputs: [output]}
    txbytes = ExPlasma.encode(txn)

    %Transaction{
      txbytes: txbytes,
      outputs: [build(:payment_v1_output, %{amount: amount})]
    }
  end

  def payment_v1_factory(%{amount: amount}) do
    output_id = %{blknum: 1, txindex: 0, oindex: 0}
    input = %ExPlasma.Output{output_id: output_id}

    output_data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: amount}
    output = %ExPlasma.Output{output_type: 1, output_data: output_data}
    txn = %ExPlasma.Transaction{tx_type: 1, outputs: [output], inputs: [input]}
    txbytes = ExPlasma.encode(txn)

    %Transaction{
      txbytes: txbytes,
      inputs: [build(:input, output_id)],
      outputs: [build(:payment_v1_output, %{amount: amount})]
    }
  end

  def input_factory(attrs) do
    %Output{output_type: 1, output_id: attrs}
  end

  def payment_v1_output_factory(attrs) do
    %Output{
      output_type: 1,
      output_data: %{
        output_guard: <<1::160>>, 
        token: <<0::160>>, 
        amount: attrs.amount
      }
    }
  end

  #def deposit_transaction_factory(attrs) do
    #%{blknum: blknum} = attrs

    #%Engine.Transaction{
      #tx_type: 1,
      #tx_data: 0,
      #metadata: <<0::160>>,
      #inputs: [],
      #outputs:
        #build(:output_utxo, %{
          #blknum: blknum || :rand.uniform(100) + 1,
          #txindex: 0,
          #oindex: 0
        #})
    #}
  #end

  #def deposit_block_factory() do
    ## NB: Hax to ensure we don't use whole numbers, which are
    ## the non-deposit blocks
    #blknum = :rand.uniform(100) + 1

    #%Engine.Block{
      #number: blknum,
      #transactions:
        #build(:deposit_transaction, %{
          #blknum: blknum
        #})
    #}
  #end

  #def transaction_factory() do
    #%Engine.Transaction{
      #tx_type: 1,
      #tx_data: 0,
      #metadata: <<0::160>>,
      #inputs: [build(:input_utxo)],
      #outputs: [build(:output_utxo)]
    #}
  #end

  #def input_utxo_factory() do
    #blknum = :rand.uniform(100)

    #%Engine.Utxo{
      #blknum: blknum,
      #txindex: 0,
      #oindex: 0,
      #owner: <<1::160>>,
      #currency: <<0::160>>,
      #amount: :rand.uniform(100)
    #}
  #end

  #def spent_utxo_factory() do
    #%Engine.Utxo{
      #blknum: :rand.uniform(100),
      #txindex: 0,
      #oindex: 0,
      #owner: <<1::160>>,
      #currency: <<0::160>>,
      #amount: :random.uniform(100),
      #spending_transaction: build(:transaction)
    #}
  #end

  #def output_utxo_factory() do
    #%Engine.Utxo{
      #owner: <<1::160>>,
      #currency: <<0::160>>,
      #amount: :rand.uniform(100)
    #}
  #end
end
