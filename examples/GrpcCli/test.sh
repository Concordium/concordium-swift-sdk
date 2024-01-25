#!/usr/bin/env sh

# Script that exercises all the commands of the CLI.
# Used to be executed as SDK "unit" tests.

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
"${cli_path}" --host="${host}" --port="${port}" account next-sequence-number "${some_account_address}"
"${cli_path}" --host="${host}" --port="${port}" account info "${some_account_address}"
"${cli_path}" --host="${host}" --port="${port}" account info "${some_account_address}" --block-hash="${some_block_hash}"
