import Foundation

public enum WalletError: Error {
    case accountNotFound
    case accountAlreadyExists
}

public class Wallet {
    private let accounts: AccountRepository // TODO: add identity repo
    private let accountDerivation: SeedBasedAccountDerivation // for now we only support the seed based scheme
    private let identityRequestBuilder: SeedBasedIdentityRequestBuilder // for now we only support the seed based scheme
    private let identityRequestURLBuilder: IdentityRequestURLBuilder

    // TODO: Take identity providers/anonymity revokers (or wrap all this into some identity manager).
    public init(seed: WalletSeed, cryptoParams: CryptographicParameters, accounts: AccountRepository, identityIssuanceCallbackURL: URL) {
        self.accounts = accounts
        accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
        identityRequestBuilder = SeedBasedIdentityRequestBuilder(seed: seed, cryptoParams: cryptoParams)
        identityRequestURLBuilder = IdentityRequestURLBuilder(callbackURL: identityIssuanceCallbackURL)
    }

    // TODO: Add method to be called to insert final identity.
    // TODO: Add abstraction for opening the URL and then intercepting the callback.
    public func prepareCreateIdentity(provider: IdentityProvider, index: IdentityIndex, anonymityRevokerThreshold: RevocationThreshold) throws -> URL {
        try identityRequestURLBuilder.issuanceURLToOpen(
            baseURL: provider.metadata.issuanceStart,
            requestJSON: identityRequestBuilder.issuanceRequestJSON(
                provider: provider,
                index: index,
                anonymityRevokerThreshold: anonymityRevokerThreshold
            )
        )
    }

    public func prepareRecoverIdentity(provider: IdentityProvider, index: IdentityIndex) throws -> IdentityRecoverRequest {
        try identityRequestURLBuilder.recoveryRequestToFetch(
            baseURL: provider.metadata.recoveryStart,
            requestJSON: identityRequestBuilder.recoveryRequestJSON(
                provider: provider.info,
                index: index,
                time: Date() // FUTURE: Use 'Date.now' once platform restrictions allow it
            )
        )
    }

    // TODO: Stored identity object should know its own index?
    public func prepareCreateAccount(identity: IdentityObject, identityIndex: IdentityIndex, provider: IdentityProvider, index: CredentialCounter) throws -> WalletAccountCredential {
        let idxs = AccountCredentialSeedIndexes(
            identity: IdentitySeedIndexes(providerID: provider.info.identity, index: identityIndex),
            counter: index
        )
        let deployment = try accountDerivation.deriveCredential(
            seedIndexes: idxs,
            identity: identity,
            provider: provider,
            threshold: 1
        )
        let account = try accountDerivation.deriveAccount(credentials: [idxs])
        return .init(credential: deployment, account: account)
    }

    public func withAccount<T>(of address: AccountAddress, _ f: (Account) throws -> T) throws -> T {
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
    var credential: AccountCredential
    var account: Account

    public func sign(expiry: TransactionTime) throws -> SignedAccountCredentialDeployment {
        try account.keys.sign(deployment: credential, expiry: expiry)
    }
}
