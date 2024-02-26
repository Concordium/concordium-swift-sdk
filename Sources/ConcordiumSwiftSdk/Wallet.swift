import CryptoKit
import Foundation

public enum WalletError: Error {
    case accountNotFound
    case accountAlreadyExists
}

public class Wallet {
    private let accounts: WalletAccountRepositoryProtocol
    private let generator: DeterministicAccountGenerator // for now we only support this one scheme

    public init(accounts: WalletAccountRepositoryProtocol, generator: DeterministicAccountGenerator) {
        self.accounts = accounts
        self.generator = generator
    }

    public func createAccount(credential: AccountCredentialCoordinates) throws -> AccountAddress {
        let account = try generator.generateAccount(credentials: [credential])
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

public enum AccountGenerationError: Error {
    case noCredentials
}

public class DeterministicAccountGenerator {
    private let seed: WalletSeed
    public let commitmentKey: String

    public init(seed: WalletSeed, commitmentKey: String) {
        self.seed = seed
        self.commitmentKey = commitmentKey
    }

    public func generateAccount(credentials: [AccountCredentialCoordinates]) throws -> WalletAccount {
        guard let firstCred = credentials.first else {
            throw AccountGenerationError.noCredentials
        }
        return try WalletAccount(
            address: generateAccountAddress(firstCredential: firstCred),
            keys: generateKeys(credentials: credentials)
        )
    }

    public func generateAccountAddress(firstCredential: AccountCredentialCoordinates) throws -> AccountAddress {
        let id = try seed.id(of: firstCredential, commitmentKey: commitmentKey)
        let hash = try SHA256.hash(data: Data(hex: id))
        return AccountAddress(Data(hash))
    }

    public func generateKeys(credentials: [AccountCredentialCoordinates]) throws -> AccountKeysCurve25519 {
        try AccountKeysCurve25519(
            Dictionary(
                uniqueKeysWithValues: credentials.enumerated().map { idx, cred in
                    try (
                        CredentialIndex(idx),
                        [KeyIndex(0): Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: seed.signingKey(of: cred)))]
                    )
                }
            )
        )
    }
}
