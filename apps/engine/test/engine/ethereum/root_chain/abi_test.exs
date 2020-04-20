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

    expected_event_parsed = %{
      amount: 10,
      blknum: 1,
      currency: <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
      eth_height: 390,
      event_signature: "DepositCreated(address,uint256,address,uint256)",
      log_index: 0,
      owner: <<59, 159, 76, 29, 210, 110, 11, 229, 147, 55, 59, 29, 54, 206, 226, 0, 140, 190, 184, 55>>,
      root_chain_txhash:
        <<77, 114, 166, 63, 244, 47, 29, 181, 10, 242, 195, 110, 139, 49, 65, 1, 210, 254, 163, 224, 0, 53, 117, 243, 2,
          152, 233, 21, 63, 227, 216, 238>>
    }

    assert Abi.decode_log(deposit_created_log) == expected_event_parsed
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

    expected_event_parsed = %{
      eth_height: 410,
      event_signature: "InFlightExitInputPiggybacked(address,bytes32,uint16)",
      log_index: 0,
      output_index: 1,
      owner: <<21, 19, 171, 205, 53, 144, 162, 94, 11, 237, 132, 6, 82, 217, 87, 57, 29, 222, 153, 85>>,
      root_chain_txhash:
        <<12, 201, 229, 85, 107, 189, 110, 234, 244, 48, 47, 68, 173, 202, 33, 87, 134, 255, 8, 207, 164, 74, 52, 190,
          23, 96, 236, 166, 15, 151, 54, 79>>,
      tx_hash:
        <<255, 144, 183, 115, 3, 229, 107, 210, 48, 169, 173, 244, 166, 85, 58, 149, 245, 255, 181, 99, 72, 98, 5, 214,
          251, 162, 93, 62, 70, 89, 73, 64>>,
      omg_data: %{piggyback_type: :input}
    }

    assert Abi.decode_log(input_piggybacked_log) == expected_event_parsed
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

    expected_event_parsed = %{
      eth_height: 408,
      event_signature: "InFlightExitOutputPiggybacked(address,bytes32,uint16)",
      log_index: 1,
      output_index: 1,
      owner: <<21, 19, 171, 205, 53, 144, 162, 94, 11, 237, 132, 6, 82, 217, 87, 57, 29, 222, 153, 85>>,
      root_chain_txhash:
        <<124, 244, 58, 96, 128, 233, 150, 119, 222, 224, 178, 108, 35, 228, 105, 177, 223, 156, 251, 86, 165, 195, 242,
          160, 18, 61, 246, 237, 174, 123, 91, 94>>,
      tx_hash:
        <<255, 144, 183, 115, 3, 229, 107, 210, 48, 169, 173, 244, 166, 85, 58, 149, 245, 255, 181, 99, 72, 98, 5, 214,
          251, 162, 93, 62, 70, 89, 73, 64>>,
      omg_data: %{piggyback_type: :output}
    }

    assert Abi.decode_log(output_piggybacked_log) == expected_event_parsed
  end

  test "if in flight exit started can be decoded" do
    in_flight_exit_started_log = %{
      :event_signature => "InFlightExitStarted(address,bytes32)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0xc8d61620144825f38394feb2c9c1d721a161ed67c123c3cb1af787fb366866c1",
      "blockNumber" => "0x2d6",
      "data" => "0x",
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => [
        "0xd5f1fe9d48880b57daa227004b16d320c0eb885d6c49d472d54c16a05fa3179e",
        "0x0000000000000000000000002c6a9f42318025cd6627baf21c468201622020df",
        "0x4f46053b5df585094cc652ddd8c365962a3889c2053592f18331b95a7dff620e"
      ],
      "transactionHash" => "0xf0e44af0d26443b9e5133c64f5a71f06a4d4d0d40c5e7412b5ea0dfcb2f1a133",
      "transactionIndex" => "0x0"
    }

    assert Abi.decode_log(in_flight_exit_started_log) == %{
             eth_height: 726,
             event_signature: "InFlightExitStarted(address,bytes32)",
             initiator: <<44, 106, 159, 66, 49, 128, 37, 205, 102, 39, 186, 242, 28, 70, 130, 1, 98, 32, 32, 223>>,
             log_index: 0,
             root_chain_txhash:
               <<240, 228, 74, 240, 210, 100, 67, 185, 229, 19, 60, 100, 245, 167, 31, 6, 164, 212, 208, 212, 12, 94,
                 116, 18, 181, 234, 13, 252, 178, 241, 161, 51>>,
             tx_hash:
               <<79, 70, 5, 59, 93, 245, 133, 9, 76, 198, 82, 221, 216, 195, 101, 150, 42, 56, 137, 194, 5, 53, 146,
                 241, 131, 49, 185, 90, 125, 255, 98, 14>>
           }
  end

  test "if start in flight exit can be decoded " do
    in_flight_exit_start_log =
      <<90, 82, 133, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 160, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 64, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 64, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 126, 248, 124, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 210, 32, 127, 180, 0, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18,
        141, 145, 248, 79, 186, 190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136,
        69, 99, 145, 130, 68, 244, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 93, 248, 91, 1,
        192, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145, 248, 79, 186, 190, 47, 160,
        172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 138, 199, 35, 4, 137, 232, 0, 0, 128,
        160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 210, 32, 127, 180, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 243, 154, 134, 159, 98, 231, 92, 245, 240, 191, 145, 70, 136, 166, 178,
        137, 202, 242, 4, 148, 53, 216, 230, 140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213, 192, 45, 109, 72, 200, 147,
        36, 134, 201, 157, 58, 217, 153, 229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41, 121, 105, 12, 62, 58, 98,
        28, 121, 43, 20, 191, 102, 248, 42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254,
        82, 60, 26, 207, 103, 220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220,
        156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105, 10, 4, 4, 171, 244, 206,
        186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183, 142, 250, 179, 95, 211,
        100, 201, 213, 218, 218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113, 248, 66, 67, 68, 37, 84, 131,
        53, 172, 110, 105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79, 82, 159, 87, 131, 247,
        158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222, 156, 68, 111, 171, 70, 168, 210, 125,
        177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68, 227, 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173,
        81, 96, 130, 50, 76, 150, 18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236,
        4, 131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193, 100, 196, 116, 232, 36, 56,
        23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219,
        110, 65, 67, 74, 18, 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123, 227,
        142, 186, 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67, 148, 138, 52,
        65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172, 125, 201, 221, 121, 168,
        12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50, 165, 106, 58,
        112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84, 186, 233, 24, 152, 208,
        58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126, 177, 120, 30, 38, 242, 5, 0, 36,
        12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31, 218, 185, 181, 48, 208, 214, 231, 232,
        116, 110, 120, 191, 159, 32, 244, 232, 111, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 65,
        52, 191, 197, 222, 130, 0, 246, 100, 25, 133, 115, 123, 250, 19, 77, 122, 226, 50, 133, 34, 71, 195, 27, 188,
        147, 104, 200, 235, 121, 231, 64, 251, 107, 58, 88, 55, 118, 117, 53, 9, 224, 81, 93, 0, 167, 62, 195, 202, 233,
        207, 237, 254, 185, 95, 207, 246, 144, 69, 242, 160, 58, 161, 96, 70, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>

    assert Abi.decode_function(in_flight_exit_start_log) == %{
             in_flight_tx:
               <<248, 124, 1, 225, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
                 210, 32, 127, 180, 0, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145,
                 248, 79, 186, 190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136,
                 69, 99, 145, 130, 68, 244, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
             in_flight_tx_sigs: [
               <<52, 191, 197, 222, 130, 0, 246, 100, 25, 133, 115, 123, 250, 19, 77, 122, 226, 50, 133, 34, 71, 195,
                 27, 188, 147, 104, 200, 235, 121, 231, 64, 251, 107, 58, 88, 55, 118, 117, 53, 9, 224, 81, 93, 0, 167,
                 62, 195, 202, 233, 207, 237, 254, 185, 95, 207, 246, 144, 69, 242, 160, 58, 161, 96, 70, 28>>
             ],
             input_inclusion_proofs: [
               <<243, 154, 134, 159, 98, 231, 92, 245, 240, 191, 145, 70, 136, 166, 178, 137, 202, 242, 4, 148, 53, 216,
                 230, 140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213, 192, 45, 109, 72, 200, 147, 36, 134, 201, 157, 58,
                 217, 153, 229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41, 121, 105, 12, 62, 58, 98, 28, 121, 43, 20,
                 191, 102, 248, 42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226, 255, 60, 124, 39, 59, 254, 82, 60,
                 26, 207, 103, 220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34, 253, 84, 214, 50, 220,
                 156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105, 10, 4, 4, 171,
                 244, 206, 186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183, 142,
                 250, 179, 95, 211, 100, 201, 213, 218, 218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113,
                 248, 66, 67, 68, 37, 84, 131, 53, 172, 110, 105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26,
                 103, 2, 51, 79, 82, 159, 87, 131, 247, 158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132,
                 159, 222, 156, 68, 111, 171, 70, 168, 210, 125, 177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68, 227,
                 203, 192, 69, 202, 186, 201, 218, 54, 202, 224, 64, 173, 81, 96, 130, 50, 76, 150, 18, 124, 242, 159,
                 69, 53, 235, 91, 126, 186, 207, 226, 161, 214, 211, 170, 184, 236, 4, 131, 211, 32, 121, 168, 89, 255,
                 112, 249, 33, 89, 112, 168, 190, 235, 177, 193, 100, 196, 116, 232, 36, 56, 23, 76, 142, 235, 111, 188,
                 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155, 234, 236, 172, 91, 69, 219, 110, 65, 67, 74, 18,
                 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111, 55, 228, 20, 51, 123, 227, 142, 186,
                 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59, 224, 94, 67, 148, 138, 52, 65,
                 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172, 125, 201, 221, 121,
                 168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77, 228, 85, 50,
                 165, 106, 58, 112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193, 84,
                 186, 233, 24, 152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126,
                 177, 120, 30, 38, 242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31,
                 218, 185, 181, 48, 208, 214, 231, 232, 116, 110, 120, 191, 159, 32, 244, 232, 111, 6>>
             ],
             input_txs: [
               <<248, 91, 1, 192, 246, 245, 1, 243, 148, 118, 78, 248, 3, 28, 17, 248, 220, 42, 92, 18, 141, 145, 248,
                 79, 186, 190, 47, 160, 172, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 138,
                 199, 35, 4, 137, 232, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
             ],
             input_utxos_pos: [2_002_000_000_000]
           }
  end

  test "if exit started can be decoded" do
    exit_started_log = %{
      :event_signature => "ExitStarted(address,uint160)",
      "address" => "0x92ce4d7773c57d96210c46a07b89acf725057f21",
      "blockHash" => "0x1bee6f75c74ceeb4817dc160e2fb56dd1337a9fc2980a2b013252cf1e620f246",
      "blockNumber" => "0x2f7",
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

    assert Abi.decode_log(exit_started_log) == %{
             eth_height: 759,
             event_signature: "ExitStarted(address,uint160)",
             exit_id: 961_120_214_746_159_734_848_620_722_848_998_552_444_082_017,
             log_index: 1,
             owner: <<8, 133, 129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204, 97, 218, 39, 84, 94, 154>>,
             root_chain_txhash:
               <<74, 130, 72, 184, 138, 23, 178, 190, 76, 96, 134, 161, 152, 70, 34, 222, 26, 96, 221, 163, 201, 221,
                 158, 206, 30, 249, 126, 209, 142, 250, 2, 140>>
           }
  end

  test "if start standard exit can be decoded" do
    start_standard_exit_log =
      <<112, 224, 20, 98, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 209, 228, 228, 234, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 96, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 224, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 93, 248, 91, 1, 192, 246, 245, 1, 243, 148, 8, 133,
        129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204, 97, 218, 39, 84, 94, 154, 148, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 13, 224, 182, 179, 167, 100, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 243, 154, 134, 159, 98, 231, 92, 245, 240, 191,
        145, 70, 136, 166, 178, 137, 202, 242, 4, 148, 53, 216, 230, 140, 92, 94, 109, 5, 228, 73, 19, 243, 78, 213,
        192, 45, 109, 72, 200, 147, 36, 134, 201, 157, 58, 217, 153, 229, 216, 148, 157, 195, 190, 59, 48, 88, 204, 41,
        121, 105, 12, 62, 58, 98, 28, 121, 43, 20, 191, 102, 248, 42, 243, 111, 0, 245, 251, 167, 1, 79, 160, 193, 226,
        255, 60, 124, 39, 59, 254, 82, 60, 26, 207, 103, 220, 63, 95, 160, 128, 166, 134, 165, 160, 208, 92, 61, 72, 34,
        253, 84, 214, 50, 220, 156, 192, 75, 22, 22, 4, 110, 186, 44, 228, 153, 235, 154, 247, 159, 94, 185, 73, 105,
        10, 4, 4, 171, 244, 206, 186, 252, 124, 255, 250, 56, 33, 145, 183, 221, 158, 125, 247, 120, 88, 30, 111, 183,
        142, 250, 179, 95, 211, 100, 201, 213, 218, 218, 212, 86, 155, 109, 212, 127, 127, 234, 186, 250, 53, 113, 248,
        66, 67, 68, 37, 84, 131, 53, 172, 110, 105, 13, 208, 113, 104, 216, 188, 91, 119, 151, 156, 26, 103, 2, 51, 79,
        82, 159, 87, 131, 247, 158, 148, 47, 210, 205, 3, 246, 229, 90, 194, 207, 73, 110, 132, 159, 222, 156, 68, 111,
        171, 70, 168, 210, 125, 177, 227, 16, 15, 39, 90, 119, 125, 56, 91, 68, 227, 203, 192, 69, 202, 186, 201, 218,
        54, 202, 224, 64, 173, 81, 96, 130, 50, 76, 150, 18, 124, 242, 159, 69, 53, 235, 91, 126, 186, 207, 226, 161,
        214, 211, 170, 184, 236, 4, 131, 211, 32, 121, 168, 89, 255, 112, 249, 33, 89, 112, 168, 190, 235, 177, 193,
        100, 196, 116, 232, 36, 56, 23, 76, 142, 235, 111, 188, 140, 180, 89, 75, 136, 201, 68, 143, 29, 64, 176, 155,
        234, 236, 172, 91, 69, 219, 110, 65, 67, 74, 18, 43, 105, 92, 90, 133, 134, 45, 142, 174, 64, 179, 38, 143, 111,
        55, 228, 20, 51, 123, 227, 142, 186, 122, 181, 187, 243, 3, 208, 31, 75, 122, 224, 127, 215, 62, 220, 47, 59,
        224, 94, 67, 148, 138, 52, 65, 138, 50, 114, 80, 156, 67, 194, 129, 26, 130, 30, 92, 152, 43, 165, 24, 116, 172,
        125, 201, 221, 121, 168, 12, 194, 240, 95, 111, 102, 76, 157, 187, 46, 69, 68, 53, 19, 125, 160, 108, 228, 77,
        228, 85, 50, 165, 106, 58, 112, 7, 162, 208, 198, 180, 53, 247, 38, 249, 81, 4, 191, 166, 231, 7, 4, 111, 193,
        84, 186, 233, 24, 152, 208, 58, 26, 10, 198, 249, 180, 94, 71, 22, 70, 226, 85, 90, 199, 158, 63, 232, 126, 177,
        120, 30, 38, 242, 5, 0, 36, 12, 55, 146, 116, 254, 145, 9, 110, 96, 209, 84, 90, 128, 69, 87, 31, 218, 185, 181,
        48, 208, 214, 231, 232, 116, 110, 120, 191, 159, 32, 244, 232, 111, 6>>

    assert Abi.decode_function(start_standard_exit_log) == %{
             output_tx:
               <<248, 91, 1, 192, 246, 245, 1, 243, 148, 8, 133, 129, 36, 179, 184, 128, 198, 139, 54, 15, 211, 25, 204,
                 97, 218, 39, 84, 94, 154, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 136, 13,
                 224, 182, 179, 167, 100, 0, 0, 128, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
             utxo_pos: 2_001_000_000_000
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
end
