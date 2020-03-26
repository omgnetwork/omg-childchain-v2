ENV_TEST ?= env MIX_ENV=test

.PHONY: test

test:
	$(ENV_TEST) mix test --exclude integration
