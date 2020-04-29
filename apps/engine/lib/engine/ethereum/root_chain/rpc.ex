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
defmodule Engine.Ethereum.RootChain.Rpc do
  @moduledoc """
   Does RPC calls for enriching event functions or bare events polling to plasma contracts.

    The reason why these public functions allow opts is that if we 
    let [url: "asdf"] through to Ethereumex, the request will be sent to that URL.

    This will allow us to run integration tests concurrently!
  """
  alias ExPlasma.Encoding

  require Logger

  @type option :: {:url, String.t()}
  @type block :: non_neg_integer()
  @type signatures :: list(String.t()) | String.t()
  @type contracts :: list(String.t()) | String.t()

  @spec transaction_receipt(String.t(), keyword()) :: {:ok, map()} | {:error, map() | binary() | atom()}
  def transaction_receipt(tx_hash, opts) do
    Ethereumex.HttpClient.eth_get_transaction_receipt(tx_hash, opts)
  end

  @spec call_contract(String.t(), String.t(), any(), keyword()) :: {:ok, binary()} | {:error, map() | binary() | atom()}
  def call_contract(contract, signature, args, opts) do
    data = signature |> ABI.encode(args) |> Encoding.to_hex()
    Ethereumex.HttpClient.eth_call(%{to: contract, data: data}, "latest", opts)
  end

  @spec get_ethereum_height(keyword()) :: {:ok, map()} | {:error, map() | binary() | atom()}
  def get_ethereum_height(opts) do
    Ethereumex.HttpClient.eth_block_number(opts)
  end

  @spec eth_get_logs(map(), keyword()) :: {:ok, list(map())} | {:error, map() | binary() | atom()}
  def eth_get_logs(params, opts) do
    Ethereumex.HttpClient.eth_get_logs(params, opts)
  end
end
