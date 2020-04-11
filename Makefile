ENV_TEST ?= env MIX_ENV=test
CHILDCHAIN_IMAGE_NAME  ?= "omisego/childchain:latest"
IMAGE_BUILDER   ?= "omisegoimages/childchain-builder:dev-90c05cb"
IMAGE_BUILD_DIR ?= $(PWD)
ENV_DEV         ?= env MIX_ENV=dev
ENV_TEST        ?= env MIX_ENV=test
ENV_PROD        ?= env MIX_ENV=prod

clean-childchain:
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

.PHONY: test

test:
	$(ENV_TEST) mix test --exclude integration

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


build-childchain-prod: deps-childchain
	$(ENV_PROD) mix do compile, release childchain --overwrite

build-childchain-dev: deps-childchain
	$(ENV_DEV) mix do compile, release childchain --overwrite

build-test: deps-childchain
	$(ENV_TEST) mix compile

.PHONY: build-prod build-dev build-test

#
# Docker
#
docker-childchain-prod:
	docker run --rm -it \
		-v $(PWD):/app \
		-u root \
		--entrypoint /bin/sh \
		$(IMAGE_BUILDER) \
		-c "cd /app && make build-childchain-prod"

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

operator_api_specs:
	swagger-cli bundle -r -t yaml -o apps/rpc/priv/swagger/operator_api_specs.yaml apps/rpc/priv/swagger/operator_api_specs/swagger.yaml

### git setup
hooks:
	git config core.hooksPath .githooks

