#!/usr/bin/env sh

# Script that exercises all the commands of the CLI.
# If the build or the execution of any of the test/sample commands fail,
# then the script will exit immediately with a non-zero status code.
# However, even if the script completed successfully,
# the output still needs to be inspected manually to assert correctness
# as no such checks are performed by the script itself.

set -eux

# Location of the gRPC interface of a Concordium Node running on testnet.
#
# Override via environment variables or use the following command to
# forward traffic for the default target (localhost:20000) to <HOST>:<PORT>:
#
#   socat TCP-LISTEN:20000,fork TCP:[IP]:[port]

host="${HOST-grpc.testnet.concordium.com}"
port="${PORT-20000}"

# Test data (picked randomly from testnet).
some_block_hash="970112d640a183b317f79ca9cc4db8cac3f1e263c68fca8c19d14b9fd2041a74"
some_account_address="33Po4Z5v4DaAHo9Gz9Afc9LRzbZmYikus4Q7gqMaXHtdS17khz"

# Build CLI.
swift build
dir_path="$(swift build --show-bin-path)"
cli_path="${dir_path}/concordium-example-client"

# Execute "tests".
"${cli_path}" generate-seed-phrase --strength=64
"${cli_path}" generate-seed-phrase --strength=128
"${cli_path}" generate-seed-phrase
"${cli_path}" --host="${host}" --port="${port}" cryptographic-parameters
"${cli_path}" --host="${host}" --port="${port}" cryptographic-parameters --block="${some_block_hash}"
"${cli_path}" account --address="${some_account_address}" next-sequence-number
"${cli_path}" account --address="${some_account_address}" info
"${cli_path}" account --address="${some_account_address}" info --block="${some_block_hash}"
"${cli_path}" --host="${host}" --port="${port}" identity-providers
"${cli_path}" --host="${host}" --port="${port}" anonymity-revokers
"${cli_path}" --host="${host}" --port="${port}" consensus-info
"${cli_path}" --host="${host}" --port="${port}" chain-parameters
"${cli_path}" --host="${host}" --port="${port}" chain-parameters --block="${some_block_hash}"
