#!/usr/bin/env sh

set -eux

# Generate bindings/bridge code.
mkdir -p ./ConcordiumWalletCrypto/Sources/ConcordiumWalletCrypto
cargo run --bin uniffi-bindgen generate src/lib.udl --language=swift --out-dir=./generated
cp ./generated/crypto.swift ./ConcordiumWalletCrypto/Sources/ConcordiumWalletCrypto/crypto.swift
mv ./generated/cryptoFFI.modulemap ./generated/module.modulemap

# Compile for Darwin (macOS) as universal binary.
cargo build --target=x86_64-apple-darwin --release
cargo build --target=aarch64-apple-darwin --release
lipo \
  ./target/x86_64-apple-darwin/release/libcrypto.a \
  ./target/aarch64-apple-darwin/release/libcrypto.a \
  -create -output=./target/universal-macos/release/libcrypto.a

# Compile for iOS.
cargo build --target=aarch64-apple-ios --release

# Compile for iOS Simulator as universal binary.
cargo build --target=x86_64-apple-ios --release
cargo build --target=aarch64-apple-ios-sim --release
lipo \
  ./target/x86_64-apple-ios/release/libcrypto.a \
  ./target/aarch64-apple-ios-sim/release/libcrypto.a \
  -create -output=./target/universal-ios/release/libcrypto.a

# Build binary framework.
xcodebuild -create-xcframework \
  -library=./target/aarch64-apple-ios/release/libcrypto.a -headers=./generated \
  -library=./target/universal-ios/release/libcrypto.a -headers=./generated \
  -library=./target/universal-macos/release/libcrypto.a -headers=./generated \
  -output=./ConcordiumWalletCrypto/RustFramework.xcframework

# Clean up.
rm -rf ./generated
