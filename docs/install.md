# Full Installation


## Prerequisites
* **[Erlang OTP](https://erlang.org/doc/installation_guide/INSTALL.html)** `>=23`
*(Note: If you have already installed Erlang, you can check the Erlang version `erlang --version`)*
* **[Elixir](https://elixir-lang.org/install.html)** `=1.10.*`
*(Note: If you have already installed Elixir, you can check the Elixir version `elixir --version`)*
* **[Rust](https://www.rust-lang.org/tools/install)**


## Setup with script
The following script will install all required prerequisites:

```
sh bin/setup
```

## Clone repo
```
git clone https://github.com/omgnetwork/childchain.git
```

## Build
```
cd childchain
mix deps.get
mix deps.compile
```

## Run tests
For a quick test (with no integration tests):
```
make init_test
mix test
```

To run integration tests (requires **not** having `geth` running in the background):
```
make init_test
mix test --trace --only integration
```