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
