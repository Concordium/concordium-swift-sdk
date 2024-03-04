import CryptoKit
import Foundation

public enum WalletError: Error {
    case accountNotFound
    case accountAlreadyExists
}

public class Wallet {
    private let cryptoParams: CryptographicParameters
    private let accounts: WalletAccountRepositoryProtocol
    private let accountGenerator: SeedBasedAccountGenerator // for now we only support this one scheme
    private let identityRequestGenerator: SeedBasedIdentityRequestGenerator // for now we only support this one scheme
    private let identityRequestUrlGenerator: WalletIdentityRequestUrlGenerator

    public init(seed: WalletSeed, cryptoParams: CryptographicParameters, accounts: WalletAccountRepositoryProtocol, identityIssuanceCallback: URL) {
        self.cryptoParams = cryptoParams
        self.accounts = accounts
        accountGenerator = SeedBasedAccountGenerator(seed: seed, commitmentKey: cryptoParams.onChainCommitmentKey)
        identityRequestGenerator = SeedBasedIdentityRequestGenerator(seed: seed)
        identityRequestUrlGenerator = WalletIdentityRequestUrlGenerator(callbackUrl: identityIssuanceCallback)
    }

    // TODO: Add method to be called to insert final identity.
    public func prepareCreateIdentity(provider: IdentityProvider, index: UInt32, anonymityRevokerThreshold: UInt8) throws -> IdentityIssuanceRequest {
        try identityRequestUrlGenerator.issuanceRequest(
            baseUrl: provider.metadata.issuanceStart,
            requestJson: identityRequestGenerator.createIssuanceRequestJson(
                provider: provider,
                index: index,
                cryptoParams: cryptoParams,
                anonymityRevokerThreshold: anonymityRevokerThreshold
            )
        )
    }

    public func prepareRecoverIdentity(provider: IdentityProvider, index: UInt32) throws -> IdentityRecoveryRequest {
        try identityRequestUrlGenerator.recoveryRequest(
            baseUrl: provider.metadata.recoveryStart,
            requestJson: identityRequestGenerator.createRecoveryRequestJson(
                provider: provider,
                index: index,
                cryptoParams: cryptoParams,
                time: Date() // FUTURE: Use 'Date.now' once platform restrictions allow it
            )
        )
    }

    public func createAccount(credential: AccountCredentialCoordinates) throws -> AccountAddress {
        let account = try accountGenerator.generateAccount(credentials: [credential])
        let address = account.address
        if try accounts.lookup(address) != nil {
            throw WalletError.accountAlreadyExists
        }
        try accounts.insert(account)
        return address
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
