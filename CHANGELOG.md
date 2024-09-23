# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Support for all transactions relevant from protocol version 7 and onwards. This includes expanding `AccountTransactionPayload`
  with the necessary variants, and corresponding constructor functions for `AccountTransaction`.
- `WalletConnectSendTransactionParam` and `WalletConnectSignMessageParam` for decoding parameters received with walletconnect requests.
- `ContractSchema`, `TypeSchema`, and `ModuleSchema` for encoding/decoding data from/to the corresponding JSON representation
- `WalletSeed.encryptionKeys` to get the encryption keys for a credential index
- `decryptAmount` and `combineEncryptedAmounts` to handle encrypted amounts
- `Statement` and `Proof` types for constructing ID statements and their corresponding proofs

#### GRPC client
- `NodeClient.status` to query transaction status.
- `SubmittedTransaction` to provide ergonomics for transactions submitted to a node.
- `NodeClient.finalizedBlocks` to query finalized blocks added from the time the query is made.
- `NodeClient.waitUntilFinalization` helper function to get the summary of a transaction and the block it is finalized into while waiting for it to be finalized.
- `NodeClient.consensusInfo` for querying the consensus info of the chain.
- `NodeClient.chainParameters` for querying the parameters of the chain.
- `NodeClient.electionInfo` for querying the election info of the chain containing data regarding active bakers and election of these.
- `NodeClient.tokenomicsInfo` for querying the tokenomics info of the chain.
- `NodeClient.source` for querying the the module source corresponding to a module reference.
- `NodeClient.invokeInstance` for running contract instance entrypoint invocations, returning an invocation result.
- `NodeClient.bakers` for querying a list of bakers/validators from the node.
- `NodeClient.poolInfo` for querying the pool info for a baker/validator identified by it's baker ID.
- `NodeClient.passiveDelegationInfo` for querying the passive delegation pool info of the chain.

### Changed

- Return type of `NodeClient.send` to `SubmittedTransaction` to provide ergonomics for working with transaction submitted to chain.
- Representation of raw data is changed from hex strings to `Data` across all functions and data structures

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
