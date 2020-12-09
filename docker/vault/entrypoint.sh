#!/bin/bash

# Vault running in the container must listen on a different port.

VAULT_CREDENTIALS="/vault/config/unseal.json"

CONFIG_DIR="/vault/config"

CA_CERT="$CONFIG_DIR/ca.crt"
CA_KEY="$CONFIG_DIR/ca.key"
TLS_KEY="$CONFIG_DIR/my-service.key"
TLS_CERT="$CONFIG_DIR/my-service.crt"
CONFIG="$CONFIG_DIR/openssl.cnf"
CSR="$CONFIG_DIR/my-service.csr"

export VAULT_ADDR="https://127.0.0.1:8200"
export VAULT_CACERT="$CA_CERT"

nohup vault server -log-level=debug -config /vault/config/vault.hcl &
VAULT_PID=$!

function unseal() {
    VAULT_INIT=$(cat $VAULT_CREDENTIALS)
    UNSEAL_KEY=$(echo $VAULT_INIT | jq -r '.unseal_keys_hex[0]')
    ROOT_TOKEN=$(echo $VAULT_INIT | jq -r .root_token)
    vault operator unseal $UNSEAL_KEY
    export VAULT_TOKEN=$ROOT_TOKEN
}

if [ -f "$VAULT_CREDENTIALS" ]; then
    echo "unseal.json exists"
    sleep 10
    unseal
    vault status
    vault secrets list
else
    echo "This entrypoint expects a snapshot, silly!"
	  exit 2
fi

# Don't exit until vault dies

wait $VAULT_PID