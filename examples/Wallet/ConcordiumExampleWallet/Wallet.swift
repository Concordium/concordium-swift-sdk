import Concordium
import Foundation

public enum WalletError: Error {
    case accountNotFound
    case accountAlreadyExists
    case identityProviderNotFound(IdentityProviderID)
}

public class Wallet {
    private let accounts: AccountRepository // TODO: add identity repo
    private let walletProxy: WalletProxy
    private let accountDerivation: SeedBasedAccountDerivation // for now we only support the seed based scheme
    private let identityRequestBuilder: SeedBasedIdentityRequestBuilder // for now we only support the seed based scheme
    private let identityRequestURLBuilder: IdentityRequestURLBuilder

    private var identityProviders: [IdentityProviderID: IdentityProvider] = [:]

    public init(
        seed: WalletSeed,
        walletProxy: WalletProxy,
        cryptoParams: CryptographicParameters,
        accounts: AccountRepository,
        identityIssuanceCallbackURL: URL
    ) {
        self.accounts = accounts
        self.walletProxy = walletProxy
        accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
        identityRequestBuilder = SeedBasedIdentityRequestBuilder(seed: seed, cryptoParams: cryptoParams)
        identityRequestURLBuilder = IdentityRequestURLBuilder(callbackURL: identityIssuanceCallbackURL)
    }

    public func refresh() async throws {
        let ips = try await walletProxy.getIdentityProviders.send(session: URLSession.shared)
        identityProviders = ips.reduce(into: [:]) { res, ip in res[ip.ipInfo.ipIdentity] = ip.toSDKType() }
    }

    // TODO: Add method to be called to insert final identity.
    // TODO: Add abstraction for opening the URL and then intercepting the callback.
    public func prepareCreateIdentity(providerID: IdentityProviderID, index: IdentityIndex, anonymityRevokerThreshold: RevocationThreshold) throws -> URL {
        guard let provider = identityProviders[providerID] else {
            throw WalletError.identityProviderNotFound(providerID)
        }
        return try identityRequestURLBuilder.issuanceURLToOpen(
            baseURL: provider.metadata.issuanceStart,
            requestJSON: identityRequestBuilder.issuanceRequestJSON(
                provider: provider,
                index: index,
                anonymityRevocationThreshold: anonymityRevokerThreshold
            )
        )
    }

    public func prepareRecoverIdentity(providerID: IdentityProviderID, index: IdentityIndex) throws -> IdentityRecoveryRequest {
        guard let provider = identityProviders[providerID] else {
            throw WalletError.identityProviderNotFound(providerID)
        }
        return try identityRequestURLBuilder.recoveryRequest(
            baseURL: provider.metadata.recoveryStart,
            requestJSON: identityRequestBuilder.recoveryRequestJSON(
                provider: provider.info,
                index: index,
                time: Date.now
            )
        )
    }

    // TODO: Stored identity object should know its own index?
    public func prepareCreateAccount(identity: SeedBasedIdentityObject, credentialCounter: CredentialCounter) throws -> WalletAccountCredential {
        let providerID = identity.indexes.providerID
        guard let provider = identityProviders[providerID] else {
            throw WalletError.identityProviderNotFound(providerID)
        }
        let deployment = try accountDerivation.deriveCredential(
            credentialCounter: credentialCounter,
            identity: identity,
            provider: provider,
            threshold: 1
        )
        let account = try accountDerivation.deriveAccount(
            credentials: [
                AccountCredentialSeedIndexes(
                    identity: identity.indexes,
                    counter: credentialCounter
                ),
            ]
        )
        return .init(credential: deployment, account: account)
    }

    public func withAccount<T>(of address: AccountAddress, _ f: (Account) throws -> T) throws -> T {
        guard let account = try accounts.lookup(address) else {
            throw WalletError.accountNotFound
        }
        return try f(account)
    }

    public func sign(_ data: Data, with account: AccountAddress) throws -> Signatures {
        try withAccount(of: account) {
            try $0.keys.sign(data)
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
    public var credential: SeedBasedAccountCredential
    public var account: Account

    public func sign(expiry: TransactionTime) throws -> SignedAccountCredentialDeployment {
        try account.keys.sign(deployment: credential.credential, expiry: expiry)
    }
}

public protocol AccountRepository {
    func lookup(_ address: AccountAddress) throws -> Account?
    func insert(_ account: Account) throws
    func remove(_ address: AccountAddress) throws
}

public class AccountStore: AccountRepository {
    private var dictionary: [AccountAddress: Account] = [:]

    public init(_ accounts: [Account] = []) {
        accounts.forEach(insert)
    }

    public func lookup(_ address: AccountAddress) -> Account? {
        dictionary[address]
    }

    public func insert(_ account: Account) {
        dictionary[account.address] = account
    }

    public func remove(_ address: AccountAddress) {
        dictionary[address] = nil
    }
}
