MAKEFLAGS += --silent
OVERRIDING_START ?= start_iex
OVERRIDING_VARIABLES ?= bin/variables
SNAPSHOT ?= SNAPSHOT_MIN_EXIT_PERIOD_SECONDS_20
BAREBUILD_ENV ?= dev
ENV_TEST ?= env MIX_ENV=test
CHILDCHAIN_IMAGE_NAME  ?= "omisego/childchain-v2:latest"
IMAGE_BUILDER   ?= "omisego/childchain-builder:dev-a21824a"
IMAGE_BUILD_DIR ?= $(PWD)
ENV_DEV         ?= env MIX_ENV=dev
ENV_TEST        ?= env MIX_ENV=test
ENV_PROD        ?= env MIX_ENV=prod
OS=$(shell uname -s)
ifeq ($(OS),Darwin)
	SSH_A_SOCK = /run/host-services/ssh-auth.sock
	SSH_A_SOCK_MOUNT = /run/host-services/ssh-auth.sock
	SSH_A_SOCK_MOUNT_VAR = /run/host-services/ssh-auth.sock
else
	SSH_A_SOCK = $$(dirname ${SSH_AUTH_SOCK})
	SSH_A_SOCK_MOUNT = /ssh-agent
	SSH_A_SOCK_MOUNT_VAR = /ssh-agent/$$(basename ${SSH_AUTH_SOCK})
endif

clean:
	rm -rf _build/*
	rm -rf deps/*
	rm -rf _build_docker/*
	rm -rf deps_docker/*

#
# Setting-up
#

deps: deps-childchain

deps-childchain:
	HEX_HTTP_TIMEOUT=120 mix deps.get

deps-prod-childchain:
	$(ENV_PROD) make deps-childchain

.PHONY: test test-console test-focus test-console-focus

init_test: init-contracts

init_test_reorg: init-contracts-reorg

test:
	$(ENV_TEST) mix test

test-focus:
	$(ENV_TEST) mix test --only focus

test-console:
	$(ENV_TEST) iex -S mix test

test-console-focus:
	$(ENV_TEST) iex -S mix test --only focus

credo:
	mix credo --strict

#
# Linting
#

format:
	mix format

check-format:
	mix format --check-formatted 2>&1

check-credo:
	$(ENV_TEST) mix credo 2>&1

check-dialyzer:
	$(ENV_TEST) mix dialyzer --halt-exit-status 2>&1

.PHONY: format check-format check-credo

#
# Building
#


build-childchain-prod: deps-prod-childchain
	$(ENV_PROD) mix do compile, release childchain --overwrite

build-childchain-dev: deps-childchain
	$(ENV_DEV) mix do compile, release childchain --overwrite

build-test: deps-childchain
	$(ENV_TEST) mix compile

.PHONY: build-prod build-dev build-test

#
# Baremetal
#

childchain: localchain_contract_addresses.env
	echo "Building Childchain" && \
	make build-childchain-${BAREBUILD_ENV} && \
	rm -f ./_build/${BAREBUILD_ENV}/rel/childchain/var/sys.config || true && \
	echo "Init Childchain DB" && \
	. ${OVERRIDING_VARIABLES} && \
	_build/${BAREBUILD_ENV}/rel/childchain/bin/childchain eval "Engine.ReleaseTasks.InitPostgresqlDB.migrate()" && \
	. ${OVERRIDING_VARIABLES} && \
	_build/${BAREBUILD_ENV}/rel/childchain/bin/childchain $(OVERRIDING_START)

disable_strict_host_checking:
	ssh -o StrictHostKeyChecking=no git@github.com || true
# make sure you're running eval "$(ssh-agent -s)"
# starting the ssh-agent should set `SSH_AUTH_SOCK` env var!
# https://www.rockyourcode.com/ssh-agent-could-not-open-a-connection-to-your-authentication-agent-with-fish-shell/
# after that you need to unlock your private key with: ssh-add ~/.ssh/id_rsa

docker-childchain-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-v ~/.ssh/:/home/root/.ssh \
		-v $(SSH_A_SOCK):$(SSH_A_SOCK_MOUNT) \
		-u root \
		--env ENTERPRISE=${ENTERPRISE} \
		--env SSH_AUTH_SOCK=$(SSH_A_SOCK_MOUNT_VAR) \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && make disable_strict_host_checking && make build-childchain-prod"

docker-childchain-build:
	docker build -f Dockerfile.childchain \
		--build-arg release_version=$$(cat $(PWD)/VERSION)+$$(git rev-parse --short=7 HEAD) \
		--cache-from $(CHILDCHAIN_IMAGE_NAME) \
		-t $(CHILDCHAIN_IMAGE_NAME) \
		.

docker-childchain: docker-childchain-prod docker-childchain-build

docker-push: docker
	docker push $(CHILDCHAIN_IMAGE_NAME)

docker-remote-childchain:
	docker exec -it childchain /app/bin/childchain remote

generate_v1_api_specs:
	swagger-cli bundle -r -t yaml -o apps/api/priv/swagger/v1/swagger_specs.yaml apps/api/priv/swagger/v1/swagger_specs/swagger.yaml

### Cabbage reorg docker logs

cabbage-reorg-watcher-logs:
	docker-compose -f docker-compose.yml -f docker-compose.reorg.yml -f docker-compose.specs.yml logs --follow watcher

cabbage-reorg-watcher_info-logs:
	docker-compose -f docker-compose.yml -f docker-compose.reorg.yml -f docker-compose.specs.yml logs --follow watcher_info

cabbage-reorg-childchain-logs:
	docker-compose -f docker-compose.yml -f docker-compose.reorg.yml -f docker-compose.specs.yml logs --follow childchain

cabbage-reorg-geth-logs:
	docker-compose -f docker-compose.yml -f docker-compose.reorg.yml -f docker-compose.specs.yml logs --follow | grep "geth-"

cabbage-reorgs-logs:
	docker-compose -f docker-compose.yml -f docker-compose.reorg.yml -f docker-compose.specs.yml logs --follow | grep "reorg"

### git setup
hooks:
	git config core.hooksPath .githooks

init-contracts: clean-contracts
	mkdir data/ || true && \
	URL=$$(grep "^$(SNAPSHOT)" snapshots.env | cut -d'=' -f2-) && \
	curl -o data/snapshot.tar.gz $$URL && \
	cd data && \
	tar --strip-components 1 -zxvf snapshot.tar.gz data/geth && \
	tar --exclude=data/* -xvzf snapshot.tar.gz && \
	AUTHORITY_ADDRESS=$$(cat plasma-contracts/build/authority_address) && \
	ETH_VAULT=$$(cat plasma-contracts/build/eth_vault) && \
	ERC20_VAULT=$$(cat plasma-contracts/build/erc20_vault) && \
	PAYMENT_EXIT_GAME=$$(cat plasma-contracts/build/payment_exit_game) && \
	PLASMA_FRAMEWORK_TX_HASH=$$(cat plasma-contracts/build/plasma_framework_tx_hash) && \
	PLASMA_FRAMEWORK=$$(cat plasma-contracts/build/plasma_framework) && \
	PAYMENT_EIP712_LIBMOCK=$$(cat plasma-contracts/build/paymentEip712LibMock) && \
	MERKLE_WRAPPER=$$(cat plasma-contracts/build/merkleWrapper) && \
	ERC20_MINTABLE=$$(cat plasma-contracts/build/erc20Mintable) && \
	sh ../bin/generate-localchain-env AUTHORITY_ADDRESS=$$AUTHORITY_ADDRESS ETH_VAULT=$$ETH_VAULT \
	ERC20_VAULT=$$ERC20_VAULT PAYMENT_EXIT_GAME=$$PAYMENT_EXIT_GAME \
	PLASMA_FRAMEWORK_TX_HASH=$$PLASMA_FRAMEWORK_TX_HASH PLASMA_FRAMEWORK=$$PLASMA_FRAMEWORK \
	PAYMENT_EIP712_LIBMOCK=$$PAYMENT_EIP712_LIBMOCK MERKLE_WRAPPER=$$MERKLE_WRAPPER ERC20_MINTABLE=$$ERC20_MINTABLE

init-contracts-vault: clean-contracts
	mkdir data/ || true && \
	URL=$$(grep "^VAULT_$(SNAPSHOT)" snapshots.env | cut -d'=' -f2-) && \
	echo $$URL && \
	curl -o data/snapshot.tar.gz $$URL && \
	cd data && \
	tar --strip-components 1 -zxvf snapshot.tar.gz data/geth && \
	tar --exclude=data/* --exclude=immutability/* -xvzf snapshot.tar.gz && \
	tar -xvzf snapshot.tar.gz immutability/ && \
	AUTHORITY_ADDRESS=$$(cat plasma-contracts/build/authority_address) && \
	ETH_VAULT=$$(cat plasma-contracts/build/eth_vault) && \
	ERC20_VAULT=$$(cat plasma-contracts/build/erc20_vault) && \
	PAYMENT_EXIT_GAME=$$(cat plasma-contracts/build/payment_exit_game) && \
	PLASMA_FRAMEWORK_TX_HASH=$$(cat plasma-contracts/build/plasma_framework_tx_hash) && \
	PLASMA_FRAMEWORK=$$(cat plasma-contracts/build/plasma_framework) && \
	PAYMENT_EIP712_LIBMOCK=$$(cat plasma-contracts/build/paymentEip712LibMock) && \
	MERKLE_WRAPPER=$$(cat plasma-contracts/build/merkleWrapper) && \
	ERC20_MINTABLE=$$(cat plasma-contracts/build/erc20Mintable) && \
	VAULT_TOKEN=$$(cat immutability/config/unseal.json | jq ."root_token" | tr -d '"') && \
	sh ../bin/generate-localchain-env VAULT_TOKEN=$$VAULT_TOKEN AUTHORITY_ADDRESS=$$AUTHORITY_ADDRESS ETH_VAULT=$$ETH_VAULT \
	ERC20_VAULT=$$ERC20_VAULT PAYMENT_EXIT_GAME=$$PAYMENT_EXIT_GAME \
	PLASMA_FRAMEWORK_TX_HASH=$$PLASMA_FRAMEWORK_TX_HASH PLASMA_FRAMEWORK=$$PLASMA_FRAMEWORK \
	PAYMENT_EIP712_LIBMOCK=$$PAYMENT_EIP712_LIBMOCK MERKLE_WRAPPER=$$MERKLE_WRAPPER ERC20_MINTABLE=$$ERC20_MINTABLE

init-contracts-reorg: clean-contracts
	mkdir data1/ || true && \
	mkdir data2/ || true && \
	mkdir data/ || true && \
	URL=$$(grep "SNAPSHOT" snapshot_reorg.env | cut -d'=' -f2-) && \
	curl -o data1/snapshot.tar.gz $$URL && \
	cd data1 && \
	tar --strip-components 1 -zxvf snapshot.tar.gz data/geth && \
	tar --exclude=data/* -xvzf snapshot.tar.gz && \
        mv snapshot.tar.gz ../data2/snapshot.tar.gz && \
	cd ../data2 && \
	tar --strip-components 1 -zxvf snapshot.tar.gz data/geth && \
	tar --exclude=data/* -xvzf snapshot.tar.gz && \
        mv snapshot.tar.gz ../data/snapshot.tar.gz && \
	cd ../data && \
	tar --strip-components 1 -zxvf snapshot.tar.gz data/geth && \
	tar --exclude=data/* -xvzf snapshot.tar.gz && \
	AUTHORITY_ADDRESS=$$(cat plasma-contracts/build/authority_address) && \
	ETH_VAULT=$$(cat plasma-contracts/build/eth_vault) && \
	ERC20_VAULT=$$(cat plasma-contracts/build/erc20_vault) && \
	PAYMENT_EXIT_GAME=$$(cat plasma-contracts/build/payment_exit_game) && \
	PLASMA_FRAMEWORK_TX_HASH=$$(cat plasma-contracts/build/plasma_framework_tx_hash) && \
	PLASMA_FRAMEWORK=$$(cat plasma-contracts/build/plasma_framework) && \
	PAYMENT_EIP712_LIBMOCK=$$(cat plasma-contracts/build/paymentEip712LibMock) && \
	MERKLE_WRAPPER=$$(cat plasma-contracts/build/merkleWrapper) && \
	ERC20_MINTABLE=$$(cat plasma-contracts/build/erc20Mintable) && \
	sh ../bin/generate-localchain-env AUTHORITY_ADDRESS=$$AUTHORITY_ADDRESS ETH_VAULT=$$ETH_VAULT \
	ERC20_VAULT=$$ERC20_VAULT PAYMENT_EXIT_GAME=$$PAYMENT_EXIT_GAME \
	PLASMA_FRAMEWORK_TX_HASH=$$PLASMA_FRAMEWORK_TX_HASH PLASMA_FRAMEWORK=$$PLASMA_FRAMEWORK \
	PAYMENT_EIP712_LIBMOCK=$$PAYMENT_EIP712_LIBMOCK MERKLE_WRAPPER=$$MERKLE_WRAPPER ERC20_MINTABLE=$$ERC20_MINTABLE

clean-contracts:
	rm -rf data/*

get-alarm:
	echo "Childchain alarms" ; \
	curl -s -X GET http://localhost:9656/v1/health.check
