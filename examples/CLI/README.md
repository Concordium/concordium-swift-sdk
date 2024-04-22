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
Due to the way the argument parser works, these options must be provided before the first subcommand; i.e. like
```shell
concordium-example-client --host=<host> --port=<port> cryptographic-parameters
```
This applies generally: all arguments to a given subcommand must be provided before the next subcommand.

Use `concordium-example-client --help` to explore the full set of commands and arguments.

The script [`./test.sh`](./test.sh) invokes all read-only commands.
This will reveal if any of the commands exit with failure.
Note, however, that it only "checks" if the commands exit successfully;
it does not make assertions about the outputs.
Use the environment variables `HOST` and `PORT` to specify the gRPC endpoint to use in the script.

By default, the CLI depends on the SDK as the local package on path `../..`.
Flip the commented out dependency in `Package.swift` to use the `main` branch of the GitHub repository instead.

See the [SDK docs](../../README.md) for details on the variables to use if you need to use a local crypto library
instead of a released one.

## Example Commands

All the commands support the options  `--host` and `--port` to configure the gRPC client as explained above.

### Account Inspection

See `concordium-example-client account --help` and the examples in [`./test.sh`](./test.sh).

### Cryptographic Parameters

Fetch and print the cryptographic parameters of the network that the connected Node belongs to:

```shell
concordium-example-client cryptographic-parameters
```

### Wallet

All `wallet` commands use a seed phrase to derive cryptographic keys and identifiers.
The commands accept the seed phrase as a space-separated string provided to the option `--seed-phrase`.
This is very insecure - production tools that serve real users must never expect sensitive information like this
to be provided as part of the command.

Apart from the seed phrase, the derived keys etc. are also tied to a particular network (mainnet or testnet).
For the reasons above, these commands are intended to be used on test networks only.
To use it (at your own risk) on mainnet, add `--network=Mainnet` right after the `wallet` component.

#### Identity

##### Issuance

Create a new identity with "index" 2 on the identity provider with ID 1:

```shell
concordium-example-client wallet --seed-phrase="gospel bicycle..." --identity-provider-id=1 --identity-index=2 identity issue
```

The command opens the identity verification flow in a browser using macOS's `open` program.
The callback from the identity provider containing the status URL is received via a temporary web server.

The created identity is carelessly dumped into the console.

##### Recovery

Recover the identity created using the [Issuance](#issuance) command above:

```shell
concordium-example-client wallet --seed-phrase="gospel bicycle..." --identity-provider-id=1 --identity-index=2 identity recover
```

The recovered identity is carelessly dumped into the console.

##### Create Account

Register an account with "counter" 0 using identity created using the [Issuance](#issuance) command above:

```shell
concordium-example-client wallet --seed-phrase="gospel bicycle..." --identity-provider-id=1 --identity-index=2 identity create-account --credential-counter=0
```

The command uses identity recovery to fetch the identity, derives a single account credential and deploys it to the chain.
The hash of the submitted transaction is printed to the console.

#### Transfer

Send 123456789 µCCD (123.456789 CCD) from the account created using the [Create Account](#create-account) command above
to account `39MD...`.

```shell
concordium-example-client wallet --seed-phrase="gospel bicycle..." --identity-provider-id=1 --identity-index=2 transfer --credential-counter=0 --receiver=<receiver-address> --amount=123456789
```

The hash of the submitted transaction is printed to the console.

### Legacy Wallet

All `legacy-wallet` commands decrypt a Legacy Wallet export file to obtain the keys for the account to interact with.
The path to the export file is provided to option `--export-file`.
The password to decrypt the file is provided as a plain text string to the option `--export-file-password`.
This is very insecure - production tools that serve real users must never expect sensitive information like this
to be provided as part of the command.

#### Transfer

From legacy account `33Po...` stored in export file `concordium-backup.concordiumwallet` under password `xxxxxx`,
send 123456789 µCCD (123.456789 CCD) to account `39MD...`.

```shell
concordium-example-client legacy-wallet --export-file=concordium-backup.concordiumwallet --export-file-password=xxxxxx --account="33Po..." transfer --receiver="39MD..." --amount=123456789
```

The hash of the submitted transaction is printed to the console.
