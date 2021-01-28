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
      :event_signature => "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[],bytes[])",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xc8d61620144825f38394feb2c9c1d721a161ed67c123c3cb1af787fb366866c1",
      "blockNumber" => "0x2d6",
      "data" =>
        "0x0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000000a5f8a301e1a0000000000000000000000000000000000000000000000000000000003b9aca00f85ced01eb9464727d219b68f2db584283583591883cd9cc342694000000000000000000000000000000000000000005ed01eb9464727d219b68f2db584283583591883cd9cc34269400000000000000000000000000000000000000000480a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000003b9aca00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000041d64506ec32843fed58aa6731c38f3fa8b81256e900abbbcd56c8ad5168a44e452d2fd3f0cd4330b8d4fe935b8d1ad151eb8a75d6a3e65dac866450c211c746af1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000055f85301c0eeed01eb9464727d219b68f2db584283583591883cd9cc34269400000000000000000000000000000000000000000a80a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0x9650546f63f8c929f52c753e240b0ee1e90d3af599016f3db6ff97066e0bd0f1",
        "0x00000000000000000000000064727d219b68f2db584283583591883cd9cc3426",
        "0x25f01fb32ff429c90a178a54dfbe5561ce67dafa2d5c65a1a8c3ccea2dd3531d"
      ],
      "transactionHash" => "0xf0e44af0d26443b9e5133c64f5a71f06a4d4d0d40c5e7412b5ea0dfcb2f1a133",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(in_flight_exit_started_log, keccak_signatures_pair()) ==
             %Event{
               eth_height: 726,
               event_signature: "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[],bytes[])",
               log_index: 0,
               root_chain_tx_hash:
                 <<240, 228, 74, 240, 210, 100, 67, 185, 229, 19, 60, 100, 245, 167, 31, 6, 164, 212, 208, 212, 12, 94,
                   116, 18, 181, 234, 13, 252, 178, 241, 161, 51>>,
               data: %{
                 "initiator" => "dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&",
                 "in_flight_tx" =>
                   "\xF8\xA3\x01\xE1\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0;\x9A\xCA\0\xF8\\\xED\x01\xEB\x94dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x05\xED\x01\xEB\x94dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\x04\x80\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0",
                 "input_txs" => [
                   "\xF8S\x01\xC0\xEE\xED\x01\xEB\x94dr}!\x9Bh\xF2\xDBXB\x83X5\x91\x88<\xD9\xCC4&\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\n\x80\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                 ],
                 "tx_hash" => "%\xF0\x1F\xB3/\xF4)\xC9\n\x17\x8AT߾Ua\xCEg\xDA\xFA-\\e\xA1\xA8\xC3\xCC\xEA-\xD3S\x1D",
                 "in_flight_tx_witnesses" => [
                   "\xD6E\x06\xEC2\x84?\xEDX\xAAg1Ï?\xA8\xB8\x12V\xE9\0\xAB\xBB\xCDVȭQh\xA4NE-/\xD3\xF0\xCDC0\xB8\xD4\xFE\x93[\x8D\x1A\xD1Q\xEB\x8Au֣\xE6]\xAC\x86dP\xC2\x11\xC7F\xAF\e"
                 ],
                 "input_utxos_pos" => [1_000_000_000]
               }
             }
  end

  test "if exit started can be decoded" do
    exit_started_log = %{
      :event_signature => "ExitStarted(address,uint168,uint256,bytes)",
      "address" => "0x0d39f15b6432c7e8a028dc5bd8c874f54852265f",
      "blockHash" => "0x9269e6dbfe6fb8fc2a7fd088b63bce77ce37f01798544ffdd5273b9a85803fe5",
      "blockNumber" => "0x349",
      "data" =>
        "0x0000000000000000000000047b7c1bf35c82a6b6a91465ce5469fe235c6f5479000000000000000000000000000000000000000000000000000000e8d4a5100000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000076f87401e1a0000000000000000000000000000000000000000000000000000000003b9aca00eeed01eb943b9f4c1dd26e0be593373b1d36cee2008cbeb8379400000000000000000000000000000000000000000980a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      "logIndex" => "0x1",
      "removed" => false,
      "topics" => [
        "0xbe1fcee8d584647b0ce80e56f62c950e0cb2126418f52cc052a665e5f85a5d93",
        "0x0000000000000000000000003b9f4c1dd26e0be593373b1d36cee2008cbeb837"
      ],
      "transactionHash" => "0x37d0ee1c1df5f2ee0874218461d396e20723d63dcc57e01c8516b880066428c3",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(exit_started_log, keccak_signatures_pair()) == %Engine.Ethereum.RootChain.Event{
             data: %{
               "exit_id" => 6_550_980_141_382_864_406_435_341_734_958_993_618_605_523_817_593,
               "owner" => ";\x9FL\x1D\xD2n\v\xE5\x937;\x1D6\xCE\xE2\0\x8C\xBE\xB87",
               "utxo_pos" => 1_000_000_000_000,
               "output_tx" =>
                 "\xF8t\x01\xE1\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0;\x9A\xCA\0\xEE\xED\x01\xEB\x94;\x9FL\x1D\xD2n\v\xE5\x937;\x1D6\xCE\xE2\0\x8C\xBE\xB87\x94\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\t\x80\xA0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
             },
             eth_height: 841,
             event_signature: "ExitStarted(address,uint168,uint256,bytes)",
             log_index: 1,
             root_chain_tx_hash:
               "7\xD0\xEE\x1C\x1D\xF5\xF2\xEE\bt!\x84aӖ\xE2\a#\xD6=\xCCW\xE0\x1C\x85\x16\xB8\x80\x06d(\xC3"
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
      "0x9650546f63f8c929f52c753e240b0ee1e90d3af599016f3db6ff97066e0bd0f1" =>
        "InFlightExitStarted(address,bytes32,bytes,uint256[],bytes[],bytes[])",
      "0xbe1fcee8d584647b0ce80e56f62c950e0cb2126418f52cc052a665e5f85a5d93" =>
        "ExitStarted(address,uint168,uint256,bytes)"
    }
  end
end
