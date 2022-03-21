# Accounts Used in Godwoken-Kicker

> This document is not for normal users, but for Godwoken-Kicker developers.

This document describes the purposes and occurrences of these accounts used by Godwoken-Kicker. All of these accounts' private keys locate on [`./accounts/`](../accounts/) directory. You can use the following commands to extra more account information.

One more thing to notice: the CKB genesis block pre-issues amount of CKB for these accounts, see [the ckb chain spec](../docker/layer1/ckb/specs/dev.toml) for more detail.

```shell
$ ls -1 accounts
ckb-miner-and-faucet.key
godwoken-block-producer.key
godwoken-eoa-register.key
polyjuice-root-account.key
rollup-genesis-cell-deployer.key
rollup-scripts-deployer.key

$ ckb-cli util key-info --privkey-path accounts/godwoken-eoa-register.key
Put this config in < ckb.toml >:

[block_assembler]
code_hash = "0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8"
hash_type = "type"
args = "0x2fb2d69092a6c9206c7f5c2348ebf0a84438bcf2"
message = "0x"

address:
  mainnet: ckb1qyqzlvkkjzf2djfqd3l4cg6ga0c2s3pchneq02k5an
  testnet: ckt1qyqzlvkkjzf2djfqd3l4cg6ga0c2s3pchneqj0gt30
lock_arg: 0x2fb2d69092a6c9206c7f5c2348ebf0a84438bcf2
lock_hash: 0xdef995f28d313531a8b2bfb2c38b933f91803cee857df6741982a4293a49f007
old-testnet-address: ckt1q9gry5zg97eddyyj5myjqmrlts3536ls4pzr308j2mc4qc
pubkey: 03b87ab0edfbc154c6cc6437a773f343ba1120825be5f2664f41ce3e4180b05aa7

$ ethereum_private_key_to_address $(cat accounts/godwoken-eoa-register.key)
0x5Afa08022F00A540FBB0F743c63d835c08056E89
```

## [CKB Miner](../accounts/ckb-miner-and-faucet.key)

  This key identities the CKB miner, using to unlock blocks cellbase. The corresponding public key is configured into [`ckb.toml` `[block_assembler]`](../docker/layer1/ckb/ckb.toml#L143-L147) under CKB's base directory.

## [CKB Faucet](../accounts/ckb-miner-and-faucet.key)

  CKB faucet uses the same key as the [CKB miner](./accounts.md#CKB%20Miner).

  Under executing `kicker deposit`, the CKB faucet transfers amount of CKBs to the given address and then deposits into layer2(Godwoken).

## [Deployer of Rollup Genesis Cell](../accounts/rollup-genesis-cell-deployer.key)

  This key identities the deployer of rollup genesis cell on layer1, using to deploy Rollup genesis cell.

  When sets up Rollup genesis cell on layer1, `gw-tools deploy-genesis` [records the public key](https://github.com/nervosnetwork/godwoken/blob/c18807b5cfaa961c230e15e3a381570c324db6f8/crates/tools/src/deploy_genesis.rs#L428-L448) of `rollup-genesis-cell-deployer.key` using [Omnilock](https://blog.cryptape.com/omnilock-a-universal-lock-that-powers-interoperability-1).

## [Deployer of Rollup Scripts (will be removed soon)](../accounts/rollup-scripts-deployer.key)

  `gw-tools deploy-scripts` uses this account to deploy rollup related scripts onto layer1.

## [Godwoken Block Producer](../accounts/godwoken-block-producer.key)

  This key identities the Godwoken block producer. 

  `gw-tools generate-config` writes its key info to `godwoken-config.toml` `[block_producer.wallet_config]` configuration section. E.g.

  ```toml
  [block_producer.wallet_config]
  # privkey: 0x182ee410e8d11e7cc7ef4e46999569ffc49060b76b2eecec1865b592bedeb178
  privkey_path = '/godwoken-block-producer.key'
  
  [block_producer.wallet_config.lock]
  code_hash = '0x9bd7e06f3ecf4be0f2fcd2188b23f1b9fcc88e5d4b65a8637b17723bbda3cce8'
  hash_type = 'type'
  args = '0x952809177232d0dba355ba5b6f4eaca39cc57746'
  ```

## [Godwoken EOA Register (will be deprecated at Godwoken v1)](../accounts/godwoken-eoa-register.key)

## [Polyjuice Root Account](../accounts/polyjuice-root-account.key)

  [godwoken/life_of_a_polyjuice_transaction.md](https://github.com/nervosnetwork/godwoken/blob/master/docs/life_of_a_polyjuice_transaction.md#root-account--deployment)

  After polyjuice root account was created by `gw-tools create-creator-account`, the resulting account id will be configured as `CREATOR_ACCOUNT_ID` to Godwoken-Web3 configuration file.
