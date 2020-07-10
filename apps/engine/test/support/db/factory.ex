defmodule Engine.DB.Factory do
  @moduledoc """
  Factories for our Ecto Schemas.
  """

  use ExMachina.Ecto, repo: Engine.Repo

  import Ecto.Changeset
  import Ecto.Query

  alias Engine.DB.Block
  alias Engine.DB.FeeRules
  alias Engine.DB.Fees
  alias Engine.DB.Output
  alias Engine.DB.Transaction
  alias Engine.Feefeed.Rules.Parser
  alias Engine.Support.TestEntity
  alias ExPlasma.Output.Position
  alias ExPlasma.PaymentV1Builder

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

    %{
      data: data,
      call_data: call_data,
      eth_height: height,
      event_signature: signature,
      log_index: log_index,
      root_chain_tx_hash: root_chain_tx_hash
    }
  end

  def deposit_transaction_factory(attr \\ %{}) do
    # Pick an available block number.
    default_blknum = sequence(:blknum, fn seq -> seq + 1 end)
    blknum = (Engine.Repo.one(from(b in Block, select: b.number)) || default_blknum) + 1
    output_guard = Map.get(attr, :output_guard) || <<1::160>>
    amount = Map.get(attr, :amount, 1)
    token = Map.get(attr, :token, <<0::160>>)
    data = %{output_guard: output_guard, token: token, amount: amount}

    id =
      %{blknum: blknum, txindex: 0, oindex: 0}
      |> Position.pos()
      |> Position.to_map()

    tx_bytes =
      PaymentV1Builder.new()
      |> PaymentV1Builder.add_output(Enum.to_list(data))
      |> PaymentV1Builder.sign!(keys: [])
      |> ExPlasma.encode()

    output = build(:output, output_id: id, output_data: data, output_type: 1, state: "confirmed")

    %Transaction{
      tx_bytes: tx_bytes,
      tx_hash: ExPlasma.hash(tx_bytes),
      outputs: [output],
      block: build(:block, number: blknum)
    }
  end

  def block_factory(attr \\ %{}) do
    %Block{
      state: attr[:state] || "confirmed",
      hash: attr[:hash] || <<0::256>>,
      number: attr[:number] || 1
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
      PaymentV1Builder.new()
      |> PaymentV1Builder.add_input(blknum: Map.get(attr, :blknum, default_blknum), txindex: 0, oindex: 0)
      |> PaymentV1Builder.add_output(output_guard: <<1::160>>, token: <<0::160>>, amount: 1)
      |> PaymentV1Builder.sign!(keys: [priv_encoded])
      |> ExPlasma.encode()

    {:ok, changeset} = Transaction.decode(tx_bytes, kind: Transaction.kind_transfer())
    apply_changes(changeset)
  end

  # The "lowest" unit in the hierarchy. This is made to form into transactions
  def output_factory(attr \\ %{}) do
    default_data = %{output_guard: <<1::160>>, token: <<0::160>>, amount: 10}
    default_blknum = sequence(:blknum, fn seq -> (seq + 1) * 1000 end)

    default_id =
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
    |> apply_changes()
  end

  def spent(%Transaction{outputs: [output]} = txn), do: %{txn | outputs: [%{output | state: "spent"}]}

  def set_state(%Transaction{outputs: [output]}, state), do: %{output | state: state}
  def set_state(%Output{} = output, state), do: %{output | state: state}

  def fees_factory() do
    %Fees{
      fee_rules_uuid: insert(:fee_rules).uuid,
      data: read_rules_file()
    }
  end

  def fee_rules_factory() do
    %FeeRules{
      data: read_rules_file()
    }
  end

  @spec read_rules_file() :: map()
  def read_rules_file() do
    {:ok, rules} = File.read("test/support/fee_rules.json")
    {:ok, file_rules} = Parser.decode_and_validate(rules)

    file_rules
  end
end
