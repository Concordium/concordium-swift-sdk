# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Support for all transactions relevant from protocol version 7 and onwards. This includes expanding `AccountTransactionPayload`
  with the necessary variants, and corresponding constructor functions for `AccountTransaction`.
- `WalletConnectSendTransactionParam` and `WalletConnectSignMessageParam` for decoding parameters received with walletconnect requests.

## [0.1.1] - 2024-04-29

### Added

- `AccountTransactionPayload.transfer(...)`: Add optional `memo` field for including a memo message in the transfer.

### Changed

- Renamed `IdentityIssuanceRequest` to `IdentityVerificationStatusRequest`.
- Renamed `IdentityRecoverRequest` to `IdentityRecoveryRequest` and changed it from being an alias
  of `HTTPRequest<Versioned<IdentityObject>>` to `HTTPRequest<IdentityRecoveryResponse>`,
  where `IdentityRecoveryResponse` is a new type that correctly decodes the error response if the recovery failed.

## [0.1.0] - 2024-04-26

First release of the SDK and an associated example CLI application.

Features:

- Creation and recovery of seed based identities.
- Creation and deployment of seed based credentials/accounts.
- Construction, signing, and sending of transfer transactions (without memo) from legacy or seed based accounts.
- Support for signing arbitrary binary messages.
- Support for decrypting and using accounts created using the legacy wallet.
- Utilities for working with amounts in CCD and fungible CIS-2 tokens.

Communication with the blockchain happens via the gRPC API except for info that's only available from Wallet Proxy.
