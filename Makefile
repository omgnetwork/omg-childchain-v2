ENV_TEST ?= env MIX_ENV=test

.PHONY: test

test:
	$(ENV_TEST) mix test --exclude integration

credo:
	mix credo --strict

### git setup
hooks:
	git config core.hooksPath .githooks
