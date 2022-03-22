#!/bin/bash

# NOTE: In `config/rollup-config.json`, `l1_sudt_cell_dep` identifies the l1_sudt cell located at the genesis block of CKB. Please type `ckb -C docker/layer1/ckb list-hash` for more information.
# NOTE: The first run of Godwoken MUST be `eth_eoa_mapping_config = null`, then deposit, finaly restart with `eth_eoa_mapping_config = <deposited user>`

set -o errexit

WORKSPACE="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
CONFIG_DIR="$WORKSPACE/config"
ACCOUNTS_DIR="${ACCOUNTS_DIR:-"ACCOUNTS_DIR is required"}"
CKB_MINER_PID=""
GODWOKEN_PID=""
COMPATIBLE_CHAIN_ID=1984

function start-ckb-miner-at-background() {
    log "start"
    ckb -C $CONFIG_DIR miner &> /dev/null &
    CKB_MINER_PID=$!
}

function stop-ckb-miner() {
    log "start"
    if [ ! -z "$CKB_MINER_PID" ]; then
        kill $CKB_MINER_PID
        CKB_MINER_PID=""
    fi
}

function start-godwoken-at-background() {
    log "start"
    godwoken run -c $CONFIG_DIR/godwoken-config.toml & # &> /dev/null &
    GODWOKEN_PID=$!
    while true; do
        sleep 1
        result=$(curl http://127.0.0.1:8119 &> /dev/null || echo "godwoken not started")
        if [ "$result" != "godwoken not started" ]; then
            break
        fi
    done
}

function stop-godwoken() {
    log "start"
    if [ ! -z "$GODWOKEN_PID" ]; then
        kill $GODWOKEN_PID
        GODWOKEN_PID=""
    fi
}

# The scripts-config.json file records the names and locations of all scripts
# that have been compiled in docker image. These compiled scripts will be
# deployed, and the deployment result will be stored into scripts-deployment.json.
# 
# To avoid redeploying, this command skips scripts-deployment.json if it already
# exists.
#
# More info: https://github.com/nervosnetwork/godwoken-docker-prebuilds/blob/97729b15093af6e5f002b46a74c549fcc8c28394/Dockerfile#L42-L54
function deploy-scripts() {
    log "start"
    if [ -s "$CONFIG_DIR/scripts-deployment.json" ]; then
        log "$CONFIG_DIR/scripts-deployment.json already exists, skip"
        return 0
    fi

    start-ckb-miner-at-background
    RUST_BACKTRACE=full gw-tools deploy-scripts \
        --ckb-rpc http://ckb:8114 \
        -i $CONFIG_DIR/scripts-config.json \
        -o $CONFIG_DIR/scripts-deployment.json \
        -k $ACCOUNTS_DIR/rollup-scripts-deployer.key
    stop-ckb-miner

    log "Generate file \"$CONFIG_DIR/scripts-deployment.json\""
}

function deploy-rollup-genesis() {
    log "start"
    if [ -s "$CONFIG_DIR/rollup-genesis-deployment.json" ]; then
        log "$CONFIG_DIR/rollup-genesis-deployment.json already exists, skip"
        return 0
    fi

    start-ckb-miner-at-background
    RUST_BACKTRACE=full gw-tools deploy-genesis \
        --ckb-rpc http://ckb:8114 \
        --scripts-deployment-path $CONFIG_DIR/scripts-deployment.json \
        --omni-lock-config-path $CONFIG_DIR/scripts-deployment.json \
        --rollup-config $CONFIG_DIR/rollup-config.json \
        -o $CONFIG_DIR/rollup-genesis-deployment.json \
        -k $ACCOUNTS_DIR/godwoken-block-producer.key
    stop-ckb-miner
    log "Generate file \"$CONFIG_DIR/rollup-genesis-deployment.json\""
}

function generate-godwoken-config() {
    log "start"
    if [ -s "$CONFIG_DIR/godwoken-config.toml" ]; then
        log "$CONFIG_DIR/godwoken-config.toml already exists, skip"
        return 0
    fi

    RUST_BACKTRACE=full gw-tools generate-config \
        --ckb-rpc http://ckb:8114 \
        --ckb-indexer-rpc http://ckb-indexer:8116 \
        -c $CONFIG_DIR/scripts-config.json \
        --scripts-deployment-path $CONFIG_DIR/scripts-deployment.json \
        --omni-lock-config-path $CONFIG_DIR/scripts-deployment.json \
        -g $CONFIG_DIR/rollup-genesis-deployment.json \
        --rollup-config $CONFIG_DIR/rollup-config.json \
        --privkey-path $ACCOUNTS_DIR/godwoken-block-producer.key \
        -o $CONFIG_DIR/godwoken-config.toml \
        --rpc-server-url 0.0.0.0:8119

    # some dirty modification
    if [ ! -z "$GODWOKEN_MODE" ]; then
        sed -i 's#^node_mode = .*$#node_mode = '"'$GODWOKEN_MODE'"'#' $CONFIG_DIR/godwoken-config.toml
    fi
    if [ ! -z "$STORE_PATH" ]; then
        sed -i 's#^path = .*$#path = '"'$STORE_PATH'"'#' $CONFIG_DIR/godwoken-config.toml
    fi
    sed -i 's#enable_methods = \[\]#err_receipt_ws_listen = '"'0.0.0.0:8120'"'#' $CONFIG_DIR/godwoken-config.toml

    # TODO https://github.com/nervosnetwork/godwoken/issues/616
    # update block_producer.account_id
    sed -i 's#^account_id = .*$#account_id = 2#' $CONFIG_DIR/godwoken-config.toml

    log "Generate file \"$CONFIG_DIR/godwoken-config.toml\""
}

# TODO It could be parallel
function create-polyjuice-root-account() {
    log "start"
    if [ -s "$CONFIG_DIR/polyjuice-root-account-id" ]; then
        log "$CONFIG_DIR/polyjuice-root-account-id already exists, skip"
        return 0
    fi

    start-ckb-miner-at-background
    start-godwoken-at-background
    RUST_BACKTRACE=full gw-tools deposit-ckb \
        --privkey-path $ACCOUNTS_DIR/polyjuice-root-account.key \
        --godwoken-rpc-url http://127.0.0.1:8119 \
        --ckb-rpc http://ckb:8114 \
        --scripts-deployment-path $CONFIG_DIR/scripts-deployment.json \
        --config-path $CONFIG_DIR/godwoken-config.toml \
        --capacity 2000
    RUST_BACKTRACE=full gw-tools create-creator-account \
        --privkey-path $ACCOUNTS_DIR/polyjuice-root-account.key \
        --godwoken-rpc-url http://127.0.0.1:8119 \
        --scripts-deployment-path $CONFIG_DIR/scripts-deployment.json \
        --config-path $CONFIG_DIR/godwoken-config.toml \
        --sudt-id 1 \
    > /var/tmp/gw-tools.log 2>&1
    stop-godwoken
    stop-ckb-miner

    cat /var/tmp/gw-tools.log
    tail -n 1 /var/tmp/gw-tools.log | grep -oE '[0-9]+$' > $CONFIG_DIR/polyjuice-root-account-id
    log "Generate file \"$CONFIG_DIR/polyjuice-root-account-id\""
}

function config-godwoken-eoa-register() {
    log "start"
    configured_eoa_register=$(grep -q eth_eoa_mapping_config $CONFIG_DIR/godwoken-config.toml || echo "not found")
    if [ ! "$configured_eoa_register" = "not found" ]; then
        log "eth_eoa_mapping_config configuration already exists, skip"
        return 0
    fi

    # Deposit for Godwoken EOA register
    start-ckb-miner-at-background
    start-godwoken-at-background
    RUST_BACKTRACE=full gw-tools deposit-ckb \
        --privkey-path $ACCOUNTS_DIR/godwoken-eoa-register.key \
        --godwoken-rpc-url http://127.0.0.1:8119 \
        --ckb-rpc http://ckb:8114 \
        --scripts-deployment-path $CONFIG_DIR/scripts-deployment.json \
        --config-path $CONFIG_DIR/godwoken-config.toml \
        --capacity 2000
    stop-godwoken
    stop-ckb-miner

    # Then we are allowed to configured it as EOA register.
    # Remember, Godwoken is required to restart to make EOA register works.
    echo ""                                                                                 >> $CONFIG_DIR/godwoken-config.toml
    echo "[eth_eoa_mapping_config.register_wallet_config]"                                  >> $CONFIG_DIR/godwoken-config.toml
    echo "privkey_path = '$ACCOUNTS_DIR/godwoken-eoa-register.key'"                         >> $CONFIG_DIR/godwoken-config.toml
    echo "[eth_eoa_mapping_config.register_wallet_config.lock]"                             >> $CONFIG_DIR/godwoken-config.toml
    echo "args = '0x2fb2d69092a6c9206c7f5c2348ebf0a84438bcf2'"                              >> $CONFIG_DIR/godwoken-config.toml
    echo "hash_type = 'type'"                                                               >> $CONFIG_DIR/godwoken-config.toml
    echo "code_hash = '0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8'" >> $CONFIG_DIR/godwoken-config.toml

    log "Configured Godwoken EOA register"
}

function generate-web3-config() {
    log "start"
    if [ -s "$CONFIG_DIR/web3-config.env" ]; then
        log "$CONFIG_DIR/web3-config.env already exists, skip"
        return 0
    fi

    if ! command -v jq &> /dev/null; then
        apt-get install -y jq &>/dev/null
    fi

    creator_account_id=$(cat $CONFIG_DIR/polyjuice-root-account-id)

    # TODO: get ETH_ADDRESS_REGISTRY_ACCOUNT_ID from the args of creator_script.args
    cat <<EOF > $CONFIG_DIR/web3-config.env
ROLLUP_TYPE_HASH=$(jq -r '.rollup_type_hash' $CONFIG_DIR/rollup-genesis-deployment.json)
ETH_ACCOUNT_LOCK_HASH=$(jq -r '.eth_account_lock.script_type_hash' $CONFIG_DIR/scripts-deployment.json)
POLYJUICE_VALIDATOR_TYPE_HASH=$(jq -r '.polyjuice_validator.script_type_hash' $CONFIG_DIR/scripts-deployment.json)
L2_SUDT_VALIDATOR_SCRIPT_TYPE_HASH=$(jq -r '.l2_sudt_validator.script_type_hash' $CONFIG_DIR/scripts-deployment.json)
TRON_ACCOUNT_LOCK_HASH=$(jq -r '.tron_account_lock.script_type_hash' $CONFIG_DIR/scripts-deployment.json)

DATABASE_URL=postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres:5432/$POSTGRES_DB
REDIS_URL=redis://redis:6379
GODWOKEN_JSON_RPC=http://godwoken:8119
GODWOKEN_WS_RPC_URL=ws://godwoken:8120
PORT=8024

# the COMPATIBLE_CHAIN_ID is the identifier of our godwoken devnet;
# then we can calculate the CHAIN_ID by:
#
# eth_chain_id = [0; 24] | rollup_config.compatible_chain_id::u32 | creator_account_id::u32
#
# More about chain id:
# * https://github.com/nervosnetwork/godwoken/pull/561
# * https://eips.ethereum.org/EIPS/eip-1344#specification
CREATOR_ACCOUNT_ID=$creator_account_id
COMPATIBLE_CHAIN_ID=$COMPATIBLE_CHAIN_ID
CHAIN_ID=$(($COMPATIBLE_CHAIN_ID << 32 + $creator_account_id))


# When requests "executeTransaction" RPC interface, the RawL2Transaction's
# signature can be omit. Therefore we fill the RawL2Transaction.from_id
# with this DEFAULT_FROM_ID (corresponding to DEFAULT_FROM_ADDRESS).
DEFAULT_FROM_ADDRESS=0x6daf63d8411d6e23552658e3cfb48416a6a2ca78
DEFAULT_FROM_ID=2

ETH_ADDRESS_REGISTRY_ACCOUNT_ID=3
EOF

    log "Generate file \"$CONFIG_DIR/web3-config.env\""
}

function generate-web3-indexer-config() {
    log "start"
    if [ -s "$CONFIG_DIR/web3-indexer-config.toml" ]; then
        log "$CONFIG_DIR/web3-indexer-config.toml already exists, skip"
        return 0
    fi

    source $CONFIG_DIR/web3-config.env
    cat <<EOF > $CONFIG_DIR/web3-indexer-config.toml
compatible_chain_id=$COMPATIBLE_CHAIN_ID
l2_sudt_type_script_hash="$L2_SUDT_VALIDATOR_SCRIPT_TYPE_HASH"
polyjuice_type_script_hash="$POLYJUICE_VALIDATOR_TYPE_HASH"
rollup_type_hash="$ROLLUP_TYPE_HASH"
eth_account_lock_hash="$ETH_ACCOUNT_LOCK_HASH"
tron_account_lock_hash="$TRON_ACCOUNT_LOCK_HASH"
godwoken_rpc_url="$GODWOKEN_JSON_RPC"
pg_url="$DATABASE_URL"
ws_rpc_url="$GODWOKEN_WS_RPC_URL"
EOF

    log "Generate file \"$CONFIG_DIR/web3-indexer-config.toml\""
}

function log() {
    echo "[${FUNCNAME[1]}] $1"
}

function main() {
    deploy-scripts
    deploy-rollup-genesis
    generate-godwoken-config

    # 顺序是什么吗？
    create-polyjuice-root-account
    config-godwoken-eoa-register

    generate-web3-config
    generate-web3-indexer-config
}

main "$@"
