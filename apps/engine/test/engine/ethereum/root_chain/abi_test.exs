# Copyright 2019-2020 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Engine.Ethereum.RootChain.AbiTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias Engine.Ethereum.RootChain.Abi
  alias Engine.Ethereum.RootChain.Event

  test "if deposit created event can be decoded from log" do
    deposit_created_log = %{
      :event_signature => "DepositCreated(address,uint256,address,uint256)",
      "address" => "0x4e3aeff70f022a6d4cc5947423887e7152826cf7",
      "blockHash" => "0xe5b0487de36b161f2d3e8c228ad4e1e84ab1ae25ca4d5ef53f9f03298ab3545f",
      "blockNumber" => "0x186",
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

    expected_event_parsed = %Event{
      eth_height: 390,
      event_signature: "DepositCreated(address,uint256,address,uint256)",
      log_index: 0,
      root_chain_tx_hash:
        <<77, 114, 166, 63, 244, 47, 29, 181, 10, 242, 195, 110, 139, 49, 65, 1, 210, 254, 163, 224, 0, 53, 117, 243, 2,
          152, 233, 21, 63, 227, 216, 238>>,
      data: %{
        "amount" => 10,
        "blknum" => 1,
        "depositor" => <<59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0, 140, 190, 184, 55>>,
        "token" => <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      }
    }

    assert Abi.decode_log(deposit_created_log, keccak_signatures_pair()) == expected_event_parsed
  end

  test "if input piggybacked event log can be decoded" do
    input_piggybacked_log = %{
      :event_signature => "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x6d95b14290cc2ac112f1560f2cd7aa0d747b91ec9cb1d47e11c205270d83c88c",
      "blockNumber" => "0x19a",
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

    expected_event_parsed = %Event{
      eth_height: 410,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 0,
      root_chain_tx_hash:
        <<12, 201, 229, 85, 107, 189, 110, 234, 244, 48, 47, 68, 173, 202, 33, 87, 134, 255, 8, 207, 164, 74, 52, 190,
          23, 96, 236, 166, 15, 151, 54, 79>>,
      data: %{
        "exit_target" => <<21, 19, 171, 205, 53, 144, 162, 94, 11, 237, 132, 6, 82, 217, 87, 57, 29, 222, 153, 85>>,
        "input_index" => 1,
        "tx_hash" =>
          <<255, 144, 183, 115, 3, 229, 107, 210, 48, 169, 173, 244, 166, 85, 58, 149, 245, 255, 181, 99, 72, 98, 5,
            214, 251, 162, 93, 62, 70, 89, 73, 64>>
      }
    }

    assert Abi.decode_log(input_piggybacked_log, keccak_signatures_pair()) == expected_event_parsed
  end

  test "if output piggybacked event log can be decoded" do
    output_piggybacked_log = %{
      :event_signature => "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x3e34475a29dafb28cd6deb65bc1782ccf6d73d6673d462a6d404ac0993d1e7eb",
      "blockNumber" => "0x198",
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

    expected_event_parsed = %Event{
      eth_height: 408,
      event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      root_chain_tx_hash:
        <<124, 244, 58, 96, 128, 233, 150, 119, 222, 224, 178, 108, 35, 228, 105, 177, 223, 156, 251, 86, 165, 195, 242,
          160, 18, 61, 246, 237, 174, 123, 91, 94>>,
      data: %{
        "exit_target" => <<21, 19, 171, 205, 53, 144, 162, 94, 11, 237, 132, 6, 82, 217, 87, 57, 29, 222, 153, 85>>,
        "output_index" => 1,
        "tx_hash" =>
          <<255, 144, 183, 115, 3, 229, 107, 210, 48, 169, 173, 244, 166, 85, 58, 149, 245, 255, 181, 99, 72, 98, 5,
            214, 251, 162, 93, 62, 70, 89, 73, 64>>
      }
    }

    assert Abi.decode_log(output_piggybacked_log, keccak_signatures_pair()) == expected_event_parsed
  end

  test "if in flight exit started can be decoded" do
    in_flight_exit_started_log = %{
      :event_signature => "InFlightExitStarted(address,bytes32)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xc8d61620144825f38394feb2c9c1d721a161ed67c123c3cb1af787fb366866c1",
      "blockNumber" => "0x2d6",
      "data" =>
        "0x000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000001d1e4e4ea000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x254a634e2edb606f4eb11675bef950159020723005e1c1c60a4199c68640d7c2",
        "0x0000000000000000000000002c6a9f42318025cd6627baf21c468201622020df",
        "0x4f46053b5df585094cc652ddd8c365962a3889c2053592f18331b95a7dff620e"
      ],
      "transactionHash" => "0xf0e44af0d26443b9e5133c64f5a71f06a4d4d0d40c5e7412b5ea0dfcb2f1a133",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(in_flight_exit_started_log, keccak_signatures_pair()) ==
             %Event{
               eth_height: 726,
               event_signature: "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[])",
               log_index: 0,
               root_chain_tx_hash:
                 <<240, 228, 74, 240, 210, 100, 67, 185, 229, 19, 60, 100, 245, 167, 31, 6, 164, 212, 208, 212, 12, 94,
                   116, 18, 181, 234, 13, 252, 178, 241, 161, 51>>,
               data: %{
                 "initiator" =>
                   <<44, 106, 159, 66, 49, 128, 37, 205, 102, 39, 186, 242, 28, 70, 130, 1, 98, 32, 32, 223>>,
                 "tx_hash" =>
                   <<79, 70, 5, 59, 93, 245, 133, 9, 76, 198, 82, 221, 216, 195, 101, 150, 42, 56, 137, 194, 5, 53, 146,
                     241, 131, 49, 185, 90, 125, 255, 98, 14>>,
                 "in_flight_tx" => <<0>>,
                 "in_flight_tx_witnesses" => [<<0>>],
                 "input_utxos_pos" => [2_001_000_000_000]
               }
             }
  end

  test "if exit started can be decoded" do
    exit_started_log = %{
      :event_signature => "ExitStarted(address,uint160)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x1bee6f75c74ceeb4817dc160e2fb56dd1337a9fc2980a2b013252cf1e620f246",
      "blockNumber" => "0x2f7",
      "data" =>
        "0x000000000000000000000000002b191e750d8d4d3dcad14a9c8e5a5cf0c81761000000000000000000000000000000000000000000000000000001d1e4e4ea00",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0xe0ffc2e7d623cb04e12318e11dd2c9df46dbfba8ac0c429dd49885f35785cf63",
        "0x00000000000000000000000008858124b3b880c68b360fd319cc61da27545e9a"
      ],
      "transactionHash" => "0x4a8248b88a17b2be4c6086a1984622de1a60dda3c9dd9ece1ef97ed18efa028c",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(exit_started_log, keccak_signatures_pair()) == %Engine.Ethereum.RootChain.Event{
             data: %{
               "exit_id" => 961_120_214_746_159_734_848_620_722_848_998_552_444_082_017,
               "owner" => "\b\x85\x81$\xB3\xB8\x80Ƌ6\x0F\xD3\x19\xCCa\xDA'T^\x9A",
               "utxo_pos" => 2_001_000_000_000
             },
             eth_height: 759,
             event_signature: "ExitStarted(address,uint168,uint256)",
             log_index: 1,
             root_chain_tx_hash: "J\x82H\xB8\x8A\x17\xB2\xBEL`\x86\xA1\x98F\"\xDE\x1A`ݣ\xC9ݞ\xCE\x1E\xF9~ю\xFA\x02\x8C"
           }
  end

  test "blocks(uint256) function call gets decoded properly" do
    data =
      "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

    %{
      "block_hash" =>
        <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      "block_timestamp" => 0
    } = Abi.decode_function(data, "blocks(uint256)")
  end

  test "nextChildBlock() function call gets decoded properly" do
    data =
      "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

    %{
      "block_number" => next_child_block
    } = Abi.decode_function(data, "nextChildBlock()")

    assert is_integer(next_child_block)
  end

  test "minExitPeriod() function call gets decoded properly" do
    data = "0x0000000000000000000000000000000000000000000000000000000000000014"

    %{"min_exit_period" => 20} = Abi.decode_function(data, "minExitPeriod()")
  end

  test "vaults(uint256) function call gets decoded properly" do
    data = "0x0000000000000000000000004e3aeff70f022a6d4cc5947423887e7152826cf7"

    %{"vault_address" => vault_address} = Abi.decode_function(data, "vaults(uint256)")

    assert is_binary(vault_address)
  end

  test "getVersion() function call gets decoded properly" do
    data =
      "0x0000000000000000000000000000000000000000000000" <>
        "000000000000000020000000000000000000000000000000" <>
        "000000000000000000000000000000000d312e302e342b61" <>
        "36396337363300000000000000000000000000000000000000"

    %{"version" => version} = Abi.decode_function(data, "getVersion()")

    assert is_binary(version)
  end

  test "childBlockInterval() function call gets decoded properly" do
    data = "0x00000000000000000000000000000000000000000000000000000000000003e8"

    %{"child_block_interval" => 1000} = Abi.decode_function(data, "childBlockInterval()")
  end

  defp keccak_signatures_pair() do
    %{
      "0x18569122d84f30025bb8dffb33563f1bdbfb9637f21552b11b8305686e9cb307" =>
        "DepositCreated(address,uint256,address,uint256)",
      "0x6ecd8e79a5f67f6c12b54371ada2ffb41bc128c61d9ac1e969f0aa2aca46cd78" =>
        "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      "0xa93c0e9b202feaf554acf6ef1185b898c9f214da16e51740b06b5f7487b018e5" =>
        "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      "0x254a634e2edb606f4eb11675bef950159020723005e1c1c60a4199c68640d7c2" =>
        "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[])",
      "0xe0ffc2e7d623cb04e12318e11dd2c9df46dbfba8ac0c429dd49885f35785cf63" => "ExitStarted(address,uint168,uint256)"
    }
  end
end
