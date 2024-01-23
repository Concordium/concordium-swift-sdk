#!/usr/bin/env sh

set -eux

rm -rf ./ConcordiumWalletCrypto/
cargo swift package --name=ConcordiumWalletCrypto --platforms=ios --platforms=macos --release