# Copyright 2019-2020 OmiseGO Pte Ltd

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
defmodule DepositsTests do
  use Cabbage.Feature, async: true, file: "deposits.feature"

  defwhen ~r/^Alice deposits "(?<amount>[^"]+)" ETH to the root chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end

  defthen ~r/^Alice should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end

  defwhen ~r/^Alice sends Bob "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end

  defthen ~r/^Alice should have the root chain balance changed by "(?<amount>[^"]+)" ETH$/,
          %{amount: amount},
          state do
    {:ok, state}
  end

  defthen ~r/^Bob should have "(?<amount>[^"]+)" ETH on the child chain$/,
          %{amount: amount},
          state do
    {:ok, %{}}
  end
end
