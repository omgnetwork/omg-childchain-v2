defmodule Engine.DB.Factory do
  @moduledoc """
  Factories for our Ecto Schemas.
  """

  use ExMachina.Ecto, repo: Engine.Repo

  alias Ecto.Changeset
  alias Engine.DB.Block
  alias Engine.DB.Fee
  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.Ethereum.RootChain.Event
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Output.Position

  def input_piggyback_event_factory(attr \\ %{}) do
    tx_hash = Map.get(attr, :tx_hash, <<1::256>>)
    index = Map.get(attr, :input_index, 0)

    params =
      attr
      |> Map.put(:signature, "InFlightExitInputPiggybacked(address,bytes32,uint16)")
      |> Map.put(:data, %{
        "tx_hash" => tx_hash,
        "input_index" => index
      })

    build(:event, params)
  end

  def output_piggyback_event_factory(attr \\ %{}) do
    tx_hash = Map.get(attr, :tx_hash, <<1::256>>)
    index = Map.get(attr, :output_index, 0)

    params =
      attr
      |> Map.put(:signature, "InFlightExitOutputPiggybacked(address,bytes32,uint16)")
      |> Map.put(:data, %{
        "tx_hash" => tx_hash,
        "output_index" => index
      })

    build(:event, params)
  end

  def in_flight_exit_started_event_factory(attr \\ %{}) do
    params =
      attr
      |> Map.put(:signature, "InFlightExitStarted(address,bytes32)")
      |> Map.put(:data, %{
        "initiator" => Map.get(attr, :initiator, <<1::160>>),
        "tx_hash" => Map.get(attr, :tx_hash, <<1::256>>)
      })
      |> Map.put(:call_data, %{
        "inputUtxosPos" => Map.get(attr, :positions, [1_000_000_000])
      })

    build(:event, params)
  end

  def exit_started_event_factory(attr \\ %{}) do
    position = Map.get(attr, :position, 1_000_000_000)

    params =
      attr
      |> Map.put(:signature, "ExitStarted(address,uint160)")
      |> Map.put(:call_data, %{
        "utxoPos" => position
      })

    build(:event, params)
  end

  def deposit_event_factory(attr \\ %{}) do
    params =
      attr
      |> Map.put(:signature, "DepositCreated(address,uint256,address,uint256)")
      |> Map.put(:data, %{
        "amount" => Map.get(attr, :amount, 1),
        "blknum" => Map.get(attr, :blknum, 1),
        "token" => Map.get(attr, :token, <<0::160>>),
        "depositor" => Map.get(attr, :depositor, <<1::160>>)
      })

    build(:event, params)
  end

  def event_factory(attr \\ %{}) do
    signature = Map.get(attr, :signature, "FooCalled()")
    data = Map.get(attr, :data, attr)
    call_data = Map.get(attr, :call_data, attr)
    height = Map.get(attr, :height, 100)
    log_index = Map.get(attr, :log_index, 1)
    root_chain_tx_hash = Map.get(attr, :log_index, <<1::160>>)

    %Event{
      data: data,
      call_data: call_data,
      eth_height: height,
      event_signature: signature,
      log_index: log_index,
      root_chain_tx_hash: root_chain_tx_hash
    }
  end

  def deposit_transaction_factory(attr \\ %{}) do
    blknum = Map.get(attr, :blknum, 1000)
    output_guard = Map.get(attr, :output_guard) || <<1::160>>
    amount = Map.get(attr, :amount, 1)
    token = Map.get(attr, :token, <<0::160>>)
    data = %{output_guard: output_guard, token: token, amount: amount}

    {:ok, id} =
      %{blknum: blknum, txindex: 0, oindex: 0}
      |> Position.pos()
      |> Position.to_map()

    tx_bytes =
      ExPlasma.payment_v1()
      |> Builder.new()
      |> Builder.add_output(Enum.to_list(data))
      |> Builder.sign!([])
      |> ExPlasma.encode!()

    output = build(:output, output_id: id, output_data: data, output_type: 1, state: "confirmed")
    {:ok, hash} = ExPlasma.hash(tx_bytes)

    %Transaction{
      tx_bytes: tx_bytes,
      tx_hash: hash,
      outputs: [output],
      block: build(:block, blknum: blknum)
    }
  end

  def payment_v1_transaction_factory(attr) do
    entity = TestEntity.alice()

    priv_encoded = Map.get(attr, :priv_encoded, entity.priv_encoded)
    addr = Map.get(attr, :addr, entity.addr)

    data = %{output_guard: addr, token: <<0::160>>, amount: 1}
    default_blknum = sequence(:blknum, fn seq -> (seq + 1) * 1000 end)
    insert(:output, %{output_data: data, blknum: Map.get(attr, :blknum, default_blknum), state: "confirmed"})

    tx_bytes =
      ExPlasma.payment_v1()
      |> Builder.new()
      |> Builder.add_input(blknum: Map.get(attr, :blknum, default_blknum), txindex: 0, oindex: 0)
      |> Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
      |> Builder.sign!([priv_encoded])
      |> ExPlasma.encode!()

    {:ok, changeset} = Transaction.decode(tx_bytes, Transaction.kind_transfer())
    Changeset.apply_changes(changeset)
  end

  # The "lowest" unit in the hierarchy. This is made to form into transactions
  def output_factory(attr \\ %{}) do
    default_data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: 10}
    default_blknum = sequence(:blknum, fn seq -> (seq + 1) * 1000 end)

    {:ok, default_id} =
      %{blknum: Map.get(attr, :blknum, default_blknum), txindex: 0, oindex: 0}
      |> Position.pos()
      |> Position.to_map()

    %Output{}
    |> Output.changeset(%{
      output_type: Map.get(attr, :output_type, 1),
      output_id: Map.get(attr, :output_id, default_id),
      output_data: Map.get(attr, :output_data, default_data),
      state: Map.get(attr, :state, "pending")
    })
    |> Changeset.apply_changes()
  end

  def spent(%Transaction{outputs: [output]} = txn), do: %{txn | outputs: [%{output | state: "spent"}]}

  def set_state(%Transaction{outputs: [output]}, state), do: %{output | state: state}
  def set_state(%Output{} = output, state), do: %{output | state: state}

  def block_factory(attr \\ %{}) do
    blknum = Map.get(attr, :blknum, 1000)
    _child_block_interval = 1000
    nonce = round(blknum / 1000)

    %Block{
      hash: Map.get(attr, :hash) || :crypto.strong_rand_bytes(32),
      nonce: nonce,
      blknum: blknum,
      tx_hash: :crypto.strong_rand_bytes(64),
      formed_at_ethereum_height: 1,
      submitted_at_ethereum_height: Map.get(attr, :submitted_at_ethereum_height, 1),
      attempts_counter: Map.get(attr, :attempts_counter),
      gas: 827
    }
  end

  def fee_factory(params) do
    fees =
      params[:term] ||
        %{
          1 => %{
            Base.decode16!("0000000000000000000000000000000000000000") => %{
              amount: 1,
              subunit_to_unit: 1_000_000_000_000_000_000,
              pegged_amount: 1,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_unix!(1_546_336_800)
            },
            Base.decode16!("0000000000000000000000000000000000000001") => %{
              amount: 2,
              subunit_to_unit: 1_000_000_000_000_000_000,
              pegged_amount: 1,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_unix!(1_546_336_800)
            }
          },
          2 => %{
            Base.decode16!("0000000000000000000000000000000000000000") => %{
              amount: 2,
              subunit_to_unit: 1_000_000_000_000_000_000,
              pegged_amount: 1,
              pegged_currency: "USD",
              pegged_subunit_to_unit: 100,
              updated_at: DateTime.from_unix!(1_546_336_800)
            }
          }
        }

    hash =
      :sha256
      |> :crypto.hash(inspect(fees))
      |> Base.encode16(case: :lower)

    %Fee{
      type: params[:type] || :current_fees,
      term: fees,
      hash: params[:hash] || hash,
      inserted_at: params[:inserted_at]
    }
  end
end
