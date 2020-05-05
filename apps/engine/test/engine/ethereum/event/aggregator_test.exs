defmodule Engine.Ethereum.Event.AggregatorTest do
  use ExUnit.Case, async: true

  alias Engine.Ethereum.Event.Aggregator
  alias Engine.Ethereum.RootChain.Abi
  alias ExPlasma.Encoding

  setup do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    table = :ets.new(String.to_atom("test-#{:rand.uniform(1000)}"), [:bag, :public, :named_table])
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    event_fetcher_name = String.to_atom("test-#{:rand.uniform(1000)}")

    start_supervised(
      {Aggregator,
       opts: [url: "yolo"],
       name: event_fetcher_name,
       contracts: [],
       ets: table,
       events: [
         [name: :deposit_created, enrich: false],
         [name: :exit_started, enrich: true],
         [name: :in_flight_exit_input_piggybacked, enrich: false],
         [name: :in_flight_exit_output_piggybacked, enrich: false],
         [name: :in_flight_exit_started, enrich: true]
       ]}
    )

    {:ok, %{event_fetcher_name: event_fetcher_name, table: table}}
  end

  test "the performance of event retrieving", %{table: table, event_fetcher_name: event_fetcher_name, test: test_name} do
    defmodule test_name do
      alias Engine.Ethereum.Event.AggregatorTest

      def get_ethereum_logs(_from_block, to_block, _signatures, _contracts, _opts) do
        deposits = for n <- 1..10_000, do: AggregatorTest.deposit_created_log(n)
        {:ok, [AggregatorTest.in_flight_exit_input_piggybacked_log(to_block) | deposits]}
      end

      def get_call_data(_tx_hash) do
        {:ok, AggregatorTest.start_standard_exit_log()}
      end
    end

    from_block = 1
    to_block = 80_000
    :sys.replace_state(event_fetcher_name, fn state -> Map.put(state, :event_interface, test_name) end)
    events = event_fetcher_name |> :sys.get_state() |> Map.get(:events)
    Aggregator.deposit_created(event_fetcher_name, from_block, to_block)
    assert Enum.count(:ets.tab2list(table)) == Enum.count(events) * 80_000
  end

  describe "start_link/1 and init/1" do
    test "that events are correctly initialized ", %{event_fetcher_name: event_fetcher_name} do
      assert event_fetcher_name |> :sys.get_state() |> Map.get(:events) == [
               [
                 signature: "InFlightExitStarted(address,bytes32)",
                 name: :in_flight_exit_started,
                 enrich: true
               ],
               [
                 signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
                 name: :in_flight_exit_output_piggybacked,
                 enrich: false
               ],
               [
                 signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
                 name: :in_flight_exit_input_piggybacked,
                 enrich: false
               ],
               [
                 signature: "ExitStarted(address,uint160)",
                 name: :exit_started,
                 enrich: true
               ],
               [
                 signature: "DepositCreated(address,uint256,address,uint256)",
                 name: :deposit_created,
                 enrich: false
               ]
             ]
    end

    test "that signatures are correctly initialized ", %{event_fetcher_name: event_fetcher_name} do
      assert event_fetcher_name |> :sys.get_state() |> Map.get(:event_signatures) |> Enum.sort() ==
               Enum.sort([
                 "InFlightExitStarted(address,bytes32)",
                 "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
                 "InFlightExitInputPiggybacked(address,bytes32,uint16)",
                 "ExitStarted(address,uint160)",
                 "DepositCreated(address,uint256,address,uint256)"
               ])
    end
  end

  describe "delete_old_logs/2" do
    # we start the test with a completely empty ETS table, meaning to events were retrieved yet
    # so the first call from a ETH event listener would actually retrieve values from Infura
    test "that :number_of_events_kept_in_ets is respected and that events get deleted from ETS", %{
      event_fetcher_name: event_fetcher_name,
      table: table,
      test: test_name
    } do
      defmodule test_name do
        alias Engine.Ethereum.Event.AggregatorTest

        def get_ethereum_logs(from_block, to_block, _signatures, _contracts, _opts) do
          {:ok,
           [
             AggregatorTest.deposit_created_log(from_block),
             AggregatorTest.exit_started_log(to_block),
             AggregatorTest.in_flight_exit_output_piggybacked_log(from_block),
             AggregatorTest.in_flight_exit_input_piggybacked_log(to_block)
           ]}
        end

        def get_call_data(_tx_hash) do
          {:ok, AggregatorTest.start_standard_exit_log()}
        end
      end

      from_block = 1
      to_block = 3
      :sys.replace_state(event_fetcher_name, fn state -> Map.put(state, :event_interface, test_name) end)
      :sys.replace_state(event_fetcher_name, fn state -> Map.put(state, :number_of_events_kept_in_ets, 1) end)
      events = event_fetcher_name |> :sys.get_state() |> Map.get(:events)

      # create data that we need
      deposit_created = deposit_created_log_decoded(from_block)

      deposit_created_2 = deposit_created_log_decoded(from_block + 1)

      exit_started_log =
        to_block
        |> exit_started_log_decoded()
        |> Map.put(:call_data, start_standard_exit_log() |> Encoding.to_binary() |> Abi.decode_function())

      in_flight_exit_output_piggybacked_log = in_flight_exit_output_piggybacked_log_decoded(from_block)

      in_flight_exit_input_piggybacked_log = in_flight_exit_input_piggybacked_log_decoded(to_block)

      data = [
        {from_block, get_signature_from_event(events, :deposit_created), [deposit_created]},
        {from_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked),
         [in_flight_exit_output_piggybacked_log]},
        {from_block, get_signature_from_event(events, :in_flight_exit_started), []},
        {from_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
         [in_flight_exit_input_piggybacked_log]},
        {from_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
        # this deposit will get called out below
        {from_block + 1, get_signature_from_event(events, :deposit_created), [deposit_created_2]},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_started), []},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_input_piggybacked), []},
        {from_block + 1, get_signature_from_event(events, :exit_started), []},
        {to_block, get_signature_from_event(events, :deposit_created), []},
        {to_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
        {to_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
        {to_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
         [in_flight_exit_input_piggybacked_log]},
        {to_block, get_signature_from_event(events, :in_flight_exit_started), []}
      ]

      _ = :ets.insert(table, data)

      from_block_2 = 2
      to_block_2 = 3
      # this should induce a ETS delete call
      assert Aggregator.deposit_created(event_fetcher_name, from_block_2, to_block_2) ==
               {:ok, [deposit_created_2]}

      what_should_be_left_in_db = [
        {from_block + 1, get_signature_from_event(events, :deposit_created), [deposit_created_2]},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_started), []},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_input_piggybacked), []},
        {from_block + 1, get_signature_from_event(events, :exit_started), []},
        {to_block, get_signature_from_event(events, :deposit_created), []},
        {to_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
        {to_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
        {to_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
         [in_flight_exit_input_piggybacked_log]},
        {to_block, get_signature_from_event(events, :in_flight_exit_started), []}
      ]

      # we're just making sure that handle continue gets called after handle_call
      :ok = Process.sleep(100)
      assert Enum.sort(:ets.tab2list(table)) == Enum.sort(what_should_be_left_in_db)
    end
  end

  describe "api calls/2 calls/3 and store_logs/4" do
    # We also assert if blocks that did NOT have any events get commited to ETS as empty.
    # This is important because we do not want to re-scan blocks for which we know contain nothing.
    test "if we get response for range and all events are commited to ETS", %{
      event_fetcher_name: event_fetcher_name,
      table: table,
      test: test_name
    } do
      defmodule test_name do
        alias Engine.Ethereum.Event.AggregatorTest

        def get_ethereum_logs(from_block, to_block, _signatures, _contracts, _opts) do
          {:ok,
           [
             AggregatorTest.deposit_created_log(from_block),
             AggregatorTest.deposit_created_log(from_block + 1),
             AggregatorTest.exit_started_log(to_block),
             AggregatorTest.in_flight_exit_output_piggybacked_log(from_block),
             AggregatorTest.in_flight_exit_input_piggybacked_log(to_block)
           ]}
        end

        def get_call_data(_tx_hash) do
          {:ok, AggregatorTest.start_standard_exit_log()}
        end
      end

      # we need to set the RPC module with our mocked implementation
      :sys.replace_state(event_fetcher_name, fn state -> Map.put(state, :event_interface, test_name) end)
      # we read the events from the aggregators state so that we're able to build the
      # event data later
      events = event_fetcher_name |> :sys.get_state() |> Map.get(:events)

      from_block = 1
      to_block = 3

      # we need to create events that we later expect when we call the aggregator APIs
      # for example, deposit_created and deposit_created_2 are expected if the range is from 1 to 3

      deposit_created = deposit_created_log_decoded(from_block)

      deposit_created_2 = deposit_created_log_decoded(from_block + 1)

      exit_started_log =
        to_block
        |> exit_started_log_decoded()
        |> Map.put(:call_data, start_standard_exit_log() |> Encoding.to_binary() |> Abi.decode_function())

      in_flight_exit_output_piggybacked_log = in_flight_exit_output_piggybacked_log_decoded(from_block)

      in_flight_exit_input_piggybacked_log = in_flight_exit_input_piggybacked_log_decoded(to_block)

      assert Aggregator.deposit_created(event_fetcher_name, from_block, to_block) ==
               {:ok, [deposit_created, deposit_created_2]}

      assert Aggregator.exit_started(event_fetcher_name, from_block, to_block) == {:ok, [exit_started_log]}

      assert Aggregator.in_flight_exit_piggybacked(event_fetcher_name, from_block, to_block) ==
               {:ok, [in_flight_exit_input_piggybacked_log, in_flight_exit_output_piggybacked_log]}

      # and now we're asserting that the API calls actually stored the events above
      # also that the events were stored at the right blknum key
      assert Enum.sort(:ets.tab2list(table)) ==
               Enum.sort([
                 {from_block, get_signature_from_event(events, :deposit_created), [deposit_created]},
                 {from_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked),
                  [in_flight_exit_output_piggybacked_log]},
                 {from_block, get_signature_from_event(events, :in_flight_exit_started), []},
                 {from_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked), []},
                 {from_block, get_signature_from_event(events, :exit_started), []},
                 {from_block + 1, get_signature_from_event(events, :deposit_created), [deposit_created_2]},
                 {from_block + 1, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
                 {from_block + 1, get_signature_from_event(events, :in_flight_exit_started), []},
                 {from_block + 1, get_signature_from_event(events, :in_flight_exit_input_piggybacked), []},
                 {from_block + 1, get_signature_from_event(events, :exit_started), []},
                 {to_block, get_signature_from_event(events, :deposit_created), []},
                 {to_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
                 {to_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
                 {to_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
                  [in_flight_exit_input_piggybacked_log]},
                 {to_block, get_signature_from_event(events, :in_flight_exit_started), []}
               ])
    end

    test "if we get response for range where from equals to and that all events are commited to ETS", %{
      event_fetcher_name: event_fetcher_name,
      table: table,
      test: test_name
    } do
      defmodule test_name do
        alias Engine.Ethereum.Event.AggregatorTest

        def get_ethereum_logs(from_block, to_block, _signatures, _contracts, _opts) do
          {:ok,
           [
             AggregatorTest.deposit_created_log(from_block),
             AggregatorTest.exit_started_log(to_block),
             AggregatorTest.in_flight_exit_output_piggybacked_log(from_block),
             AggregatorTest.in_flight_exit_input_piggybacked_log(to_block)
           ]}
        end

        def get_call_data(_tx_hash) do
          {:ok, AggregatorTest.start_standard_exit_log()}
        end
      end

      :sys.replace_state(event_fetcher_name, fn state -> Map.put(state, :event_interface, test_name) end)
      from_block = 1
      to_block = 1
      deposit_created = deposit_created_log_decoded(from_block)

      assert Aggregator.deposit_created(event_fetcher_name, from_block, to_block) ==
               {:ok, [deposit_created]}

      exit_started_log =
        to_block
        |> exit_started_log_decoded()
        |> Map.put(:call_data, start_standard_exit_log() |> Encoding.to_binary() |> Abi.decode_function())

      assert Aggregator.exit_started(event_fetcher_name, from_block, to_block) == {:ok, [exit_started_log]}

      in_flight_exit_output_piggybacked_log = in_flight_exit_output_piggybacked_log_decoded(from_block)

      in_flight_exit_input_piggybacked_log = in_flight_exit_input_piggybacked_log_decoded(to_block)

      assert Aggregator.in_flight_exit_piggybacked(event_fetcher_name, from_block, to_block) ==
               {:ok, [in_flight_exit_input_piggybacked_log, in_flight_exit_output_piggybacked_log]}

      events = event_fetcher_name |> :sys.get_state() |> Map.get(:events)

      assert Enum.sort(:ets.tab2list(table)) ==
               Enum.sort([
                 {from_block, get_signature_from_event(events, :deposit_created), [deposit_created]},
                 {to_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
                 {from_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked),
                  [in_flight_exit_output_piggybacked_log]},
                 {to_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
                  [in_flight_exit_input_piggybacked_log]},
                 {to_block, get_signature_from_event(events, :in_flight_exit_started), []}
               ])
    end
  end

  describe "get_logs/3" do
    test "that data and order (blknum) is preserved in returned data when we fetch deposits", %{
      event_fetcher_name: event_fetcher_name,
      table: table,
      test: test_name
    } do
      defmodule test_name do
        alias Engine.Ethereum.Event.AggregatorTest

        def get_ethereum_logs(_from_block, _to_block, _signatures, _contracts, _opts) do
          {:ok,
           [
             AggregatorTest.deposit_created_log(1),
             AggregatorTest.deposit_created_log(2)
           ]}
        end

        def get_call_data(_tx_hash) do
          {:ok, AggregatorTest.start_standard_exit_log()}
        end
      end

      from_block = 1
      to_block = 3
      # we get these events so that we're able to extract signatures
      # where we construct custom data
      events = event_fetcher_name |> :sys.get_state() |> Map.get(:events)

      # create data that we need
      # two deposits, one exit started and one in flight exit output piggybacked
      # and one in flight exit input piggynacked
      deposit_created = deposit_created_log_decoded(from_block)

      deposit_created_2 = deposit_created_log(from_block + 1)

      exit_started_log =
        to_block
        |> exit_started_log_decoded()
        |> Map.put(:call_data, start_standard_exit_log() |> Encoding.to_binary() |> Abi.decode_function())

      in_flight_exit_output_piggybacked_log = in_flight_exit_output_piggybacked_log_decoded(from_block)

      in_flight_exit_input_piggybacked_log = in_flight_exit_input_piggybacked_log_decoded(to_block)

      # we put the events into a list of events below
      # some are empty, others get filled by the data we created above
      # we just need to make sure, that the block number (from_block, from_block + 1, to_block)
      # coincides with the event data
      event_data = [
        {from_block, get_signature_from_event(events, :deposit_created), [deposit_created]},
        {from_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked),
         [in_flight_exit_output_piggybacked_log]},
        {from_block, get_signature_from_event(events, :in_flight_exit_started), []},
        {from_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
         [in_flight_exit_input_piggybacked_log]},
        {from_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
        # this deposit will get called out below
        {from_block + 1, get_signature_from_event(events, :deposit_created), [deposit_created_2]},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_started), []},
        {from_block + 1, get_signature_from_event(events, :in_flight_exit_input_piggybacked), []},
        {from_block + 1, get_signature_from_event(events, :exit_started), []},
        {to_block, get_signature_from_event(events, :deposit_created), []},
        {to_block, get_signature_from_event(events, :in_flight_exit_output_piggybacked), []},
        {to_block, get_signature_from_event(events, :exit_started), [exit_started_log]},
        {to_block, get_signature_from_event(events, :in_flight_exit_input_piggybacked),
         [in_flight_exit_input_piggybacked_log]},
        {to_block, get_signature_from_event(events, :in_flight_exit_started), []}
      ]

      # data gets inserted into the ETS table that the event aggregator us using
      true = :ets.insert(table, event_data)
      # we want the event aggregator to use our mocked RPC module
      :sys.replace_state(event_fetcher_name, fn state -> Map.put(state, :event_interface, test_name) end)
      # we assert that if we pull deposits in the from_block and to_block range
      # the deposits that we created above are returned in the correct order
      # and that there's no more non *empty* deposits, only those that we defined
      {:ok, data} = Aggregator.deposit_created(event_fetcher_name, from_block, to_block)
      assert Enum.at(data, 0) == deposit_created
      assert Enum.at(data, 1) == deposit_created_2
      # we defined two, so there shouldn't be any more!
      assert Enum.at(data, 2) == nil
    end
  end

  describe "handle_call/3, forward_call/5" do
    test "that APIs dont allow weird range (where from_block is bigger then to_block)", %{
      event_fetcher_name: event_fetcher_name
    } do
      from = 3
      to = 1

      assert Aggregator.deposit_created(event_fetcher_name, from, to) == {:error, :check_range}

      assert Aggregator.in_flight_exit_started(event_fetcher_name, from, to) ==
               {:error, :check_range}

      assert Aggregator.in_flight_exit_piggybacked(event_fetcher_name, from, to) ==
               {:error, :check_range}

      assert Aggregator.exit_started(event_fetcher_name, from, to) == {:error, :check_range}
    end
  end

  # data that we extracted into helper functions
  def deposit_created_log(block_number) do
    %{
      "address" => "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
      "blockHash" => "0xe5b0487de36b161f2d3e8c228ad4e1e84ab1ae25ca4d5ef53f9f03298ab3545f",
      "blockNumber" => "0x" <> Integer.to_string(block_number, 16),
      "data" => "0x000000000000000000000000000000000000000000000000000000000000000a",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x18569122d84f30025bb8dffb33563f1bdbfb9637f21552b11b8305686e9cb307",
        "0x0000000000000000000000003b9f4c1dd26e0be593373b1d36cee2008cbeb837",
        "0x0000000000000000000000000000000000000000000000000000000000000001",
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      ],
      "transactionHash" => "0x4d72a63ff42f1db50af2c36e8b314101d2fea3e0003575f30298e9153fe3d8ee",
      "transactionIndex" => "0x0"
    }
  end

  def exit_started_log(block_number) do
    %{
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x1bee6f75c74ceeb4817dc160e2fb56dd1337a9fc2980a2b013252cf1e620f246",
      "blockNumber" => "0x" <> Integer.to_string(block_number, 16),
      "data" => "0x000000000000000000000000002b191e750d8d4d3dcad14a9c8e5a5cf0c81761",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0xdd6f755cba05d0a420007aef6afc05e4889ab424505e2e440ecd1c434ba7082e",
        "0x00000000000000000000000008858124b3b880c68b360fd319cc61da27545e9a"
      ],
      "transactionHash" => "0x4a8248b88a17b2be4c6086a1984622de1a60dda3c9dd9ece1ef97ed18efa028c",
      "transactionIndex" => "0x0"
    }
  end

  def in_flight_exit_output_piggybacked_log(block_number) do
    %{
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x3e34475a29dafb28cd6deb65bc1782ccf6d73d6673d462a6d404ac0993d1e7eb",
      "blockNumber" => "0x" <> Integer.to_string(block_number, 16),
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0x6ecd8e79a5f67f6c12b54371ada2ffb41bc128c61d9ac1e969f0aa2aca46cd78",
        "0x0000000000000000000000001513abcd3590a25e0bed840652d957391dde9955",
        "0xff90b77303e56bd230a9adf4a6553a95f5ffb563486205d6fba25d3e46594940"
      ],
      "transactionHash" => "0x7cf43a6080e99677dee0b26c23e469b1df9cfb56a5c3f2a0123df6edae7b5b5e",
      "transactionIndex" => "0x0"
    }
  end

  def in_flight_exit_input_piggybacked_log(block_number) do
    %{
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x6d95b14290cc2ac112f1560f2cd7aa0d747b91ec9cb1d47e11c205270d83c88c",
      "blockNumber" => "0x" <> Integer.to_string(block_number, 16),
      "data" => "0x0000000000000000000000000000000000000000000000000000000000000001",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0xa93c0e9b202feaf554acf6ef1185b898c9f214da16e51740b06b5f7487b018e5",
        "0x0000000000000000000000001513abcd3590a25e0bed840652d957391dde9955",
        "0xff90b77303e56bd230a9adf4a6553a95f5ffb563486205d6fba25d3e46594940"
      ],
      "transactionHash" => "0x0cc9e5556bbd6eeaf4302f44adca215786ff08cfa44a34be1760eca60f97364f",
      "transactionIndex" => "0x0"
    }
  end

  def in_flight_exit_input_piggybacked_log_decoded(block_number) do
    block_number
    |> in_flight_exit_input_piggybacked_log()
    |> Abi.decode_log(keccak_signatures_pair())
  end

  def in_flight_exit_output_piggybacked_log_decoded(block_number) do
    block_number
    |> in_flight_exit_output_piggybacked_log()
    |> Abi.decode_log(keccak_signatures_pair())
  end

  def exit_started_log_decoded(block_number) do
    block_number
    |> exit_started_log()
    |> Abi.decode_log(keccak_signatures_pair())
  end

  def deposit_created_log_decoded(block_number) do
    block_number
    |> deposit_created_log()
    |> Abi.decode_log(keccak_signatures_pair())
  end

  def start_standard_exit_log() do
    "0x70e014620000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000001d1e4e4ea00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000005df85b01c0f6f501f39408858124b3b880c68b360fd319cc61da27545e9a940000000000000000000000000000000000000000880de0b6b3a764000080a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200f39a869f62e75cf5f0bf914688a6b289caf2049435d8e68c5c5e6d05e44913f34ed5c02d6d48c8932486c99d3ad999e5d8949dc3be3b3058cc2979690c3e3a621c792b14bf66f82af36f00f5fba7014fa0c1e2ff3c7c273bfe523c1acf67dc3f5fa080a686a5a0d05c3d4822fd54d632dc9cc04b1616046eba2ce499eb9af79f5eb949690a0404abf4cebafc7cfffa382191b7dd9e7df778581e6fb78efab35fd364c9d5dadad4569b6dd47f7feabafa3571f842434425548335ac6e690dd07168d8bc5b77979c1a6702334f529f5783f79e942fd2cd03f6e55ac2cf496e849fde9c446fab46a8d27db1e3100f275a777d385b44e3cbc045cabac9da36cae040ad516082324c96127cf29f4535eb5b7ebacfe2a1d6d3aab8ec0483d32079a859ff70f9215970a8beebb1c164c474e82438174c8eeb6fbc8cb4594b88c9448f1d40b09beaecac5b45db6e41434a122b695c5a85862d8eae40b3268f6f37e414337be38eba7ab5bbf303d01f4b7ae07fd73edc2f3be05e43948a34418a3272509c43c2811a821e5c982ba51874ac7dc9dd79a80cc2f05f6f664c9dbb2e454435137da06ce44de45532a56a3a7007a2d0c6b435f726f95104bfa6e707046fc154bae91898d03a1a0ac6f9b45e471646e2555ac79e3fe87eb1781e26f20500240c379274fe91096e60d1545a8045571fdab9b530d0d6e7e8746e78bf9f20f4e86f06"
  end

  def keccak_signatures_pair() do
    %{
      "0x18569122d84f30025bb8dffb33563f1bdbfb9637f21552b11b8305686e9cb307" =>
        "DepositCreated(address,uint256,address,uint256)",
      "0x6ecd8e79a5f67f6c12b54371ada2ffb41bc128c61d9ac1e969f0aa2aca46cd78" =>
        "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      "0xa93c0e9b202feaf554acf6ef1185b898c9f214da16e51740b06b5f7487b018e5" =>
        "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      "0xd5f1fe9d48880b57daa227004b16d320c0eb885d6c49d472d54c16a05fa3179e" => "InFlightExitStarted(address,bytes32)",
      "0xdd6f755cba05d0a420007aef6afc05e4889ab424505e2e440ecd1c434ba7082e" => "ExitStarted(address,uint160)"
    }
  end

  defp get_signature_from_event(events, name) do
    events
    |> Enum.find(fn event -> Keyword.get(event, :name) == name end)
    |> Keyword.get(:signature)
  end
end
