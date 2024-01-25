#!/usr/bin/env sh

# Script that exercises all the commands of the CLI.
# If the build or the execution of any of the test/sample commands fail,
# then the script will exit immediately with a non-zero status code.
# However, even if the script completed successfully,
# the output still needs to be inspected manually to assert correctness
# as no such checks are performed by the script itself.

set -eux

# Location of the gRPC interface of a Concordium Node running on mainnet.
#
# Override via environment variables or use the following command to
# forward traffic for the default target (localhost:20000) to <HOST>:<PORT>:
#
#   socat TCP-LISTEN:20000,fork TCP:[IP]:[port]

host="${HOST-localhost}"
port="${PORT-20000}"

# Test data (picked randomly from mainnet).
some_block_hash="a21c1c18b70c64680a4eceea655ab68d164e8f1c82b8b8566388391d8da81e41"
some_account_address="35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh"

# Build CLI.
swift build
dir_path="$(swift build --show-bin-path)"
cli_path="${dir_path}/GrpcCli"

# Execute "tests".
"${cli_path}" --host="${host}" --port="${port}" cryptographic-parameters
"${cli_path}" --host="${host}" --port="${port}" cryptographic-parameters --block-hash="${some_block_hash}"
"${cli_path}" --host="${host}" --port="${port}" account "${some_account_address}" next-sequence-number
"${cli_path}" --host="${host}" --port="${port}" account "${some_account_address}" info
"${cli_path}" --host="${host}" --port="${port}" account "${some_account_address}" info --block-hash="${some_block_hash}"
