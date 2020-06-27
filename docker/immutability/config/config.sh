#/bin/sh
while [[ "$(curl -k -X PUT -H "X-Vault-Request: true" -H "X-Vault-Token: totally-secure" -d '{"rpc_url":"http://geth:8545","chain_id":"1337"}' -s https://vault_server:8200/v1/immutability-eth-plugin/config | jq --raw-output ''.lease_id'')" != "" ]]; do sleep 5; done

#now we create a wallet that hosts the authority account
curl -X PUT -H "X-Vault-Request: true" -H "X-Vault-Token: totally-secure" -d 'null' http://vault_server:8200/v1/immutability-eth-plugin/wallets/AUTHORITY_WALLET
# authority account yolo this shit
curl -X PUT -H "X-Vault-Request: true" -H "X-Vault-Token: totally-secure" -d 'null' http://vault_server:8200/v1/immutability-eth-plugin/wallets/AUTHORITY_WALLET/accounts
# activate the child chain
curl -X PUT -H "X-Vault-Request: true" -H "X-Vault-Token: totally-secure" -d '{"contract":"0xd185aff7fb18d2045ba766287ca64992fdd79b1e"}' http://vault_server:8900/v1/immutability-eth-plugin/wallets/plasma-deployer/accounts/0x888a65279D4a3A4E3cbA57D5B3Bd3eB0726655a6/plasma/activateChildChain
