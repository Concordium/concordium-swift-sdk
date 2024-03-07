import CryptoKit
import Foundation

public enum WalletError: Error {
    case accountNotFound
    case accountAlreadyExists
}

public class Wallet {
    private let accounts: WalletAccountRepositoryProtocol // TODO: add identity repo
    private let accountGenerator: SeedBasedAccountGenerator // for now we only support this one scheme
    private let identityRequestGenerator: SeedBasedIdentityRequestGenerator // for now we only support this one scheme
    private let identityRequestUrlGenerator: WalletIdentityRequestUrlGenerator
    private let accountCredentialGenerator: SeedBasedAccountCredentialGenerator

    // TODO: Take identity providers/anonymity revokers (or wrap all this into some identity manager).
    public init(seed: WalletSeed, cryptoParams: CryptographicParameters, accounts: WalletAccountRepositoryProtocol, identityIssuanceCallback: URL) {
        self.accounts = accounts
        accountGenerator = SeedBasedAccountGenerator(seed: seed, commitmentKeyHex: cryptoParams.onChainCommitmentKeyHex)
        identityRequestGenerator = SeedBasedIdentityRequestGenerator(seed: seed, globalContext: cryptoParams)
        identityRequestUrlGenerator = WalletIdentityRequestUrlGenerator(callbackUrl: identityIssuanceCallback)
        accountCredentialGenerator = SeedBasedAccountCredentialGenerator(seed: seed, globalContext: cryptoParams)
    }

    // TODO: Add method to be called to insert final identity.
    // TODO: Add abstraction for opening the URL and then intercepting the callback.
    public func prepareCreateIdentity(provider: IdentityProvider, index: UInt32, anonymityRevokerThreshold: UInt8) throws -> URL {
        try identityRequestUrlGenerator.issuanceUrlToOpen(
            baseUrl: provider.metadata.issuanceStart,
            requestJson: identityRequestGenerator.issuanceRequestJson(
                provider: provider,
                index: index,
                anonymityRevokerThreshold: anonymityRevokerThreshold
            )
        )
    }

    public func prepareRecoverIdentity(provider: IdentityProvider, index: UInt32) throws -> IdentityRecoveryRequest {
        try identityRequestUrlGenerator.recoveryRequest(
            baseUrl: provider.metadata.recoveryStart,
            requestJson: identityRequestGenerator.recoveryRequestJson(
                provider: provider.info,
                index: index,
                time: Date() // FUTURE: Use 'Date.now' once platform restrictions allow it
            )
        )
    }

    // TODO: Stored identity object should know its own index?
    public func prepareCreateAccount(identity: IdentityObject, identityIndex: UInt32, provider: IdentityProvider, index: UInt8) throws -> WalletAccountCredential {
        let coordinates = AccountCredentialCoordinates(
            identity: IdentityCoordinates(providerIndex: provider.info.identity, index: identityIndex),
            counter: index
        )
        let deployment = try accountCredentialGenerator.accountCredentialDeployment(
            coordinates: coordinates,
            identity: identity,
            provider: provider,
            threshold: 1
        )
        let account = try accountGenerator.generateAccount(credentials: [coordinates])
        return .init(deployment: deployment, account: account)
    }

    public func withAccount<T>(of address: AccountAddress, _ f: (WalletAccount) throws -> T) throws -> T {
        guard let account = try accounts.lookup(address) else {
            throw WalletError.accountNotFound
        }
        return try f(account)
    }

    public func sign(_ message: Data, with account: AccountAddress) throws -> Signatures {
        try withAccount(of: account) {
            try $0.keys.sign(message: message)
        }
    }

    // TODO: Make expiry an enum that allows setting absolute time or duration from now.
    public func sign(_ transaction: AccountTransaction, sequenceNumber: SequenceNumber, expiry: TransactionTime) throws -> SignedAccountTransaction {
        try withAccount(of: transaction.sender) {
            try $0.keys.sign(transaction: transaction, sequenceNumber: sequenceNumber, expiry: expiry)
        }
    }
}

// TODO: If WalletAccount knew its credentials then this type wouldn't be needed.
public struct WalletAccountCredential {
    var deployment: AccountCredentialDeployment
    var account: WalletAccount

    public func sign(expiry: TransactionTime) throws -> SignedAccountCredentialDeployment {
        try account.keys.sign(credentialDeployment: deployment, expiry: expiry)
    }
}
