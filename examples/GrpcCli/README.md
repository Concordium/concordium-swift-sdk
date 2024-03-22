# GrpcCli

A small tool for demonstrating how to integrate the SDK as well as exercising the gRPC client
which is otherwise hard to cover with unit tests.

The CLI is organized into subcommands such as

```shell
GrpcCli cryptographic-parameters
```

for retrieving the cryptographic parameters of the chain and

```shell
GrpcCli account <account-address> info --block-hash=<block-hash>
```

for retrieving information about the account `<account-address>` as of block `<block-hash>`.

By default, the tool attempts to query the gRPC interface of a node running on `localhost:20000`.
Use the options `--host` and `--ip` (or a relay tool such as `socat`) to point it somewhere else.

Use `GrpcCli --help` to explore the full command interface.

The script [`./test.sh`](./test.sh) invokes all available commands.
This will reveal if any of the commands exit with failure.
Note, however, that it only "checks" if the commands exit successfully;
it does not make assertions about the outputs.
Use the environment variables `HOST` and `IP` to specify the gRPC endpoint to use in the script.

By default, the CLI uses the SDK currently on the `main` branch.
Set the environment variable `CONCORDIUM_SDK_PATH` to the path of a local copy of the SDK (presumably `../..`)
to use that instead.

See the SDK's readme for an explanation of the variables to set if you need to use a local crypto library as well.
