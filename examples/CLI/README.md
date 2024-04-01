# CLI

*Disclaimer: This tool is for testing/illustration purposes only.
Secrets are not handled with care.*

A small tool for demonstrating how to integrate the SDK as well as exercising the gRPC client
which is otherwise hard to cover with unit tests.

The interface is organized into subcommands such as

```shell
concordium-example-client cryptographic-parameters
```

for retrieving the cryptographic parameters of the chain and

```shell
concordium-example-client account <account-address> info --block-hash=<block-hash>
```

for retrieving information about the account `<account-address>` as of block `<block-hash>`.

By default, the tool attempts to query the gRPC interface of a node running on `localhost:20000`.
Use the options `--host` and `--port` (or a relay tool such as `socat`) to point it somewhere else.

Use `concordium-example-client --help` to explore the full set of commands and arguments.

The script [`./test.sh`](./test.sh) invokes all read-only commands.
This will reveal if any of the commands exit with failure.
Note, however, that it only "checks" if the commands exit successfully;
it does not make assertions about the outputs.
Use the environment variables `HOST` and `IP` to specify the gRPC endpoint to use in the script.

By default, the CLI uses the SDK currently on the `main` branch.
Set the environment variable `CONCORDIUM_SDK_PATH` to the path of a local copy of the SDK (presumably `../..`)
to use that instead.

See the SDK's readme for an explanation of the variables to set if you need to use a local crypto library as well.

## Commands

All the commands support the options  `<host>` and `<port>` to configure the gRPC client as explained above.

### Account Inspection

See `concordium-example-client account --help` and the examples in [`./test.sh`](./test.sh).

### Cryptographic Parameters

```shell
concordium-example-client --host=<host> --port=<port> cryptographic-parameters
```

### Wallet (Seed Based)

#### Transfer

```shell
concordium-example-client --host=<host> --port=<port> wallet --seed-phrase=<seed-phrase> --identity-provider-index=<ip-idx> --identity-index=<id-idx> --credential-counter=<cred-cnt> transfer --receiver=<receiver-address> --amount=<amount>
```

where
- `<seed-phrase>` is the seed phrase words separated by space (remember quotes!).
- `<ip-idx>`, `<id-idx>`, and `<cred-cnt>` are the "coordinates" of the sender account derived from the seed.
- `<receiver-address>` is the address of the receiving account.
- `<amount>` is the amount of uCCD to transfer.

### Legacy Wallet

#### Transfer

```shell
concordium-example-client legacy-wallet --export-file <export-file> --account=<sender-address> transfer --receiver=<receiver-address> --amount=<amount>
```

where
- `<export-file>` is the path to a file in the format of a decrypted export file from the Legacy Mobile Wallet.
- `<receiver-address>` is the address of the sender account (assumed to be present in the export file).
- `<receiver-address>` is the address of the receiving account.
- `<amount>` is the amount of uCCD to transfer.

### Identity

#### Issuance

#### Recovery
