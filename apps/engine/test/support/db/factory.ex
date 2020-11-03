defmodule Engine.DB.Factory do
  @moduledoc """
  Factories for our Ecto Schemas.
  """

  use ExMachina.Ecto, repo: Engine.Repo

  alias Engine.DB.Block
  alias Engine.DB.Fee
  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.DB.TransactionFee
  alias Engine.Ethereum.RootChain.Event
  alias Engine.Support.TestEntity
  alias ExPlasma.Builder
  alias ExPlasma.Output.Position

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
        "tx_hash" => Map.get(attr, :tx_hash, <<1::256>>),
        "input_utxos_pos" => Map.get(attr, :positions, [1_000_000_000])
      })

    build(:event, params)
  end

  def exit_started_event_factory(attr \\ %{}) do
    position = Map.get(attr, :position, 1_000_000_000)

    params =
      attr
      |> Map.put(:signature, "ExitStarted(address,uint160)")
      |> Map.put(:data, %{
        "utxo_pos" => position
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
    height = Map.get(attr, :height, 100)
    log_index = Map.get(attr, :log_index, 1)
    root_chain_tx_hash = Map.get(attr, :log_index, <<1::160>>)

    %Event{
      data: data,
      eth_height: height,
      event_signature: signature,
      log_index: log_index,
      root_chain_tx_hash: root_chain_tx_hash
    }
  end

  def deposit_output_factory(attr \\ %{}) do
    entity = TestEntity.alice()

    default_blknum = sequence(:deposit_output_blknum, fn seq -> seq + 1 end)

    blknum = Map.get(attr, :blknum, default_blknum)
    output_guard = Map.get(attr, :output_guard, entity.addr)
    amount = Map.get(attr, :amount, 1)
    token = Map.get(attr, :token, <<0::160>>)

    {:ok, encoded_output_data} =
      %ExPlasma.Output{}
      |> struct(%{
        output_type: ExPlasma.payment_v1(),
        output_data: %{
          output_guard: output_guard,
          token: token,
          amount: amount
        }
      })
      |> ExPlasma.Output.encode()

    output_id = Position.new(blknum, 0, 0)

    {:ok, encoded_output_id} =
      %ExPlasma.Output{}
      |> struct(%{output_id: output_id})
      |> ExPlasma.Output.encode(as: :input)

    %Output{
      state: :confirmed,
      output_type: ExPlasma.payment_v1(),
      output_data: encoded_output_data,
      output_id: encoded_output_id,
      position: output_id.position
    }
  end

  def payment_v1_transaction_factory(attr \\ %{}) do
    entity = TestEntity.alice()

    %{output_id: output_id} = input = :deposit_output |> build() |> set_state(:spent)
    %{output_data: output_data} = output = build(:output)

    tx_bytes =
      case attr[:tx_bytes] do
        nil ->
          ExPlasma.payment_v1()
          |> Builder.new(%{
            inputs: [ExPlasma.Output.decode_id!(output_id)],
            outputs: [ExPlasma.Output.decode!(output_data)]
          })
          |> Builder.sign!([entity.priv_encoded])
          |> ExPlasma.encode!()

        bytes ->
          bytes
      end

    {:ok, tx_hash} = ExPlasma.Transaction.hash(tx_bytes)

    %Transaction{
      inputs: Map.get(attr, :inputs, [input]),
      outputs: Map.get(attr, :outputs, [output]),
      tx_bytes: Map.get(attr, :tx_bytes, tx_bytes),
      tx_hash: tx_hash,
      tx_type: ExPlasma.payment_v1(),
      block: Map.get(attr, :block),
      tx_index: Map.get(attr, :tx_index, 0),
      inserted_at: DateTime.truncate(DateTime.utc_now(), :second),
      updated_at: DateTime.truncate(DateTime.utc_now(), :second)
    }
  end

  # The "lowest" unit in the hierarchy. This is made to form into transactions
  def output_factory(attr \\ %{}) do
    default_data = %{
      output_guard: Map.get(attr, :output_guard, <<1::160>>),
      token: Map.get(attr, :token, <<0::160>>),
      amount: Map.get(attr, :amount, 10)
    }

    default_blknum = sequence(:output_blknum, fn seq -> (seq + 1) * 1000 end)
    default_txindex = sequence(:output_txindex, fn seq -> seq + 1 end)
    default_oindex = sequence(:output_oindex, fn seq -> seq + 1 end)

    default_output_id =
      Position.new(
        Map.get(attr, :blknum, default_blknum),
        Map.get(attr, :txindex, default_txindex),
        Map.get(attr, :oindex, default_oindex)
      )

    {:ok, encoded_output_data} =
      %ExPlasma.Output{}
      |> struct(%{
        output_type: Map.get(attr, :output_type, 1),
        output_data: Map.get(attr, :output_data, default_data)
      })
      |> ExPlasma.Output.encode()

    {:ok, encoded_output_id} =
      %ExPlasma.Output{}
      |> struct(%{output_id: Map.get(attr, :output_id, default_output_id)})
      |> ExPlasma.Output.encode(as: :input)

    %Output{
      state: :pending,
      output_type: ExPlasma.payment_v1(),
      output_data: encoded_output_data,
      output_id: encoded_output_id,
      position: default_output_id.position
    }
  end

  def block_factory() do
    %Block{
      hash: :crypto.strong_rand_bytes(32),
      nonce: sequence(:block_nonce, fn seq -> seq + 1 end),
      blknum: sequence(:block_blknum, fn seq -> (seq + 1) * 1000 end),
      state: :forming,
      tx_hash: :crypto.strong_rand_bytes(64),
      formed_at_ethereum_height: 1,
      submitted_at_ethereum_height: 1,
      attempts_counter: 0,
      transactions: [],
      gas: 827
    }
  end

  def merged_fee_factory() do
    fees = %{
      1 => %{
        Base.decode16!("0000000000000000000000000000000000000000") => [1, 2],
        Base.decode16!("0000000000000000000000000000000000000001") => [1]
      },
      2 => %{Base.decode16!("0000000000000000000000000000000000000000") => [1]}
    }

    hash =
      :sha256
      |> :crypto.hash(inspect(fees))
      |> Base.encode16(case: :lower)

    %Fee{
      type: :merged_fees,
      term: fees,
      hash: hash,
      inserted_at: DateTime.utc_now()
    }
  end

  def current_fee_factory() do
    fees = %{
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
      type: :current_fees,
      term: fees,
      hash: hash,
      inserted_at: DateTime.utc_now()
    }
  end

  def transaction_fee_factory(attr) do
    %TransactionFee{
      amount: Map.fetch!(attr, :amount),
      currency: Map.fetch!(attr, :currency)
    }
  end

  defp set_state(%Output{} = output, state), do: %{output | state: state}
end
