# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `AccountTransactionPayload.transfer(...)`: Add optional `memo` field for including a memo message in the tranfer.

## [0.1.0] - 2024-04-26

First release of the SDK and an associated example CLI application.

Features:

- Creation and recovery of seed based identities.
- Creation and deployment of seed based credentials/accounts.
- Construction, signing, and sending of transfer transactions (without memo) from legacy or seed based accounts.
- Support for signing arbitrary binary messages.
- Support for decrypting and using accounts created using the legacy wallet.

Communication with the blockchain happens via the gRPC API except for info that's only available from Wallet Proxy.
