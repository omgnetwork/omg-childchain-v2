# Configuration variables

## Vault configuration variables
* If you're deploying with **Vault**, set:
  * `VAULT_URL` - the vault url.
  * `VAULT_TOKEN` - the vault token is conceptually similar to a session cookie on a web site. Once a user authenticates, Vault returns a vault token which is used for future requests. The token is used by Vault to verify the identity of the client and to enforce the applicable ACL policies. This token is passed via HTTP headers.
  * `WALLET_NAME` - the wallet name that holds the authority account.
  * `AUTHORITY_ADDRESS` - this address is used to call the setAuthority interface on the plasma network.

* If there's **no Vault**, set:
  * `PRIVATE_KEY` - the private key. 

## Other configuration variables
- `ETHEREUM_RPC_URL` - the Ethereum RPC URL.
- `FINALITY_MARGIN` - the finality margin is number of Ethereum block confirmations to count before recognizing an event, by default is set to `10`.
- `ETHEREUM_NETWORK` - the Ethereum network.
- `TX_HASH_CONTRACT` - the contract deploy transaction hash.
- `AUTHORITY_ADDRESS` - the authority address, this address is used to call the setAuthority interface on the plasma network.
- `CONTRACT_ADDRESS_PLASMA_FRAMEWORK` - the plasma framework contract address that is deployed.
- `ETHEREUM_EVENTS_CHECK_INTERVAL_MS` -  the interval that checks for Ethereum events, by default is set to `8000`.
- `ETHEREUM_STALLED_SYNC_THRESHOLD_MS` - desynchronization threshold in milliseconds, by default is set to `20000`.
- `PREPARE_BLOCK_FOR_SUBMISSION_INTERVAL_MS` - the interval for preparing block for submission in milliseconds, by default is set to `10000`.
- `FEE_CLAIMER_ADDRESS` - the address that will claim the fee.
- `DATABASE_URL` - the postgres database url.
- `ENGINE_DB_POOL_SIZE` - the size of the engine database pool, by default is set to `10`.
- `ENGINE_DB_POOL_QUEUE_TARGET_MS` - the queue target of the engine database pool, by default is set to `100`.
- `ENGINE_DB_POOL_QUEUE_INTERVAL_MS` - the queue interval of the engine database pool, by default is set to `2000`
- `FEE_FEED_URL` - the fee feed url, by default is set to `http://localhost:4000/api/v1`
- `FEE_CHANGE_TOLERANCE_PERCENT` - by default is set to `25`
- `STORED_FEE_UPDATE_INTERVAL_MINUTES` - the interval to store fee updates in minutes, by default is set to `1`.
- `SENTRY_DSN` - Sentry automatically assigns you a Data Source Name (DSN) when you create a project to start monitoring events in your app. The DSN tells the SDK where to send the events. If this variable does not exist, the SDK will just not send any events.
- `HOSTNAME` - childchain's hostname.
- `APP_ENV` - app environment, needed for sentry.
- `DD_HOSTNAME` - the monitoring service hostname, by default is set to `datadog`.
- `DD_APM_PORT` - the datadog APM port, by default is set to `8126`.
- `BATCH_SIZE` - the batch size, by default is set to `10`
- `SYNC_THRESHOLD` - the sync threshold, by default is set to `100`
- `DD_DISABLED` - to disable or not to disable datadog, by default is set to `true`
- `RULES_FETCH_INTERVAL` - number of seconds between periodic retrieval of fee rules from GitHub, by default is set to `180`
- `PORT` - the childchain port, by default is set to `9656`