<img src="docs/assets/logo.png" width="100" height="100" align="right" />

# Childchain
<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Overview](#overview)
- [Getting Started](#getting-started)
    - [Service start up using Docker Compose](#service-start-up-using-docker-compose)
    - [Troubleshooting Docker](#troubleshooting-docker)
- [Documentation](#documentation)
- [License](#license)
<!-- markdown-toc end -->

## Overview
**Childchain** is a server application written in Elixir, it collects valid transactions that move funds on the child chain, submits child chain block hashes to the root chain contract and publishes child chain block's contents.  

## Getting started

### Service start up using Docker Compose
The quickest way to get Childchain Server running is to use [Docker-Compose](https://docs.docker.com/compose/install/).

* Install [Docker](https://docs.docker.com/install/) and [Docker-Compose](https://docs.docker.com/compose/install/).
* Clone the Childchain repo:
```
git clone https://github.com/omgnetwork/childchain.git && cd childchain
```

In order to avoid possible port conflicts, make sure that the following `TCP` ports are available: 
* `9656`, `8545`, `8546`, `443`, `7434`, `7534`, `5432`, `4000`, `8555`, `8556`

All commands should be run from the root of the repo folder.

* [Configure OS environment variables](docs/configuration.md).

* To get the necessary dependencies to build the project:
```
make deps
```
- To bring the entire system up, you will first need to bring in the compatible `geth` snapshot of plasma contracts:
```
make init_test
```

- To start the server:
```
docker-compose up
```
- To start the server with only specific services up (eg: the childchain service, geth, etc...):

```
docker-compose up childchain geth ...
```
*(Note: This will also bring up any services childchain depends on.)*

### Troubleshooting Docker
If service start up is unsuccessful, containers can be left hanging, which impacts the start of services on the future attempts of `docker-compose up`.
- View all running containers:
```
docker ps
```
- Stop all running containers:
```
docker kill $(docker ps -q)
```

## Documentation
All documentations can found in the [docs](docs/) directory. It is recommended to take a look at the documentation.    

## License
The **Childchain Server** is licensed under the [Apache License](https://www.apache.org/licenses/LICENSE-2.0).