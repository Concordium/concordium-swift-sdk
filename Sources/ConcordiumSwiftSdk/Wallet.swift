import ConcordiumWalletCrypto
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

    public func createAccount(credential: AccountCredential) throws -> AccountAddress {
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

public struct Identity {
    public var providerIndex: UInt32
    public var index: UInt32

    public init(providerIndex: UInt32, index: UInt32) {
        self.providerIndex = providerIndex
        self.index = index
    }
}

public struct AccountCredential {
    public var identity: Identity
    public var counter: UInt8

    public init(identity: Identity, counter: UInt8) {
        self.identity = identity
        self.counter = counter
    }
}

public struct Issuer {
    public var index: UInt64
    public var subindex: UInt64

    public init(index: UInt64, subindex: UInt64) {
        self.index = index
        self.subindex = subindex
    }
}

public struct VerifiableCredential {
    public var issuer: Issuer
    public var index: UInt32

    public init(issuer: Issuer, index: UInt32) {
        self.issuer = issuer
        self.index = index
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

    public func generateAccount(credentials: [AccountCredential]) throws -> WalletAccount {
        guard let firstCred = credentials.first else {
            throw AccountGenerationError.noCredentials
        }
        return try WalletAccount(
            address: generateAccountAddress(firstCredential: firstCred),
            keys: generateKeys(credentials: credentials)
        )
    }

    public func generateAccountAddress(firstCredential: AccountCredential) throws -> AccountAddress {
        let id = try seed.id(of: firstCredential, commitmentKey: commitmentKey)
        let hash = try SHA256.hash(data: Data(hex: id))
        return AccountAddress(Data(hash))
    }

    public func generateKeys(credentials: [AccountCredential]) throws -> AccountKeysCurve25519 {
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

public enum Network: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

/// Class for deterministically deriving cryptographic values related to credentials from a seed.
public class WalletSeed {
    private let hex: String
    private let network: Network

    public init(hex: String, network: Network) {
        self.hex = hex
        self.network = network
    }

    public func signingKey(of credential: AccountCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func publicKey(of credential: AccountCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func id(of credential: AccountCredential, commitmentKey: String) throws -> String {
        try ConcordiumWalletCrypto.getCredentialId(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: credential.counter,
            commitmentKey: commitmentKey
        )
    }

    public func prfKey(of identity: Identity) throws -> String {
        try ConcordiumWalletCrypto.getPrfKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func credSec(of identity: Identity) throws -> String {
        try ConcordiumWalletCrypto.getIdCredSec(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func signatureBlindingRandomness(of identity: Identity) throws -> String {
        try ConcordiumWalletCrypto.getSignatureBlindingRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func attributeCommitmentRandomness(of credential: AccountCredential, attribute: UInt8) throws -> String {
        try ConcordiumWalletCrypto.getAttributeCommitmentRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter),
            attribute: attribute
        )
    }

    public func signingKey(of verifiableCredential: VerifiableCredential) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialSigningKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func publicKey(of verifiableCredential: VerifiableCredential) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialPublicKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func verifiableCredentialBackupEncryptionKey() throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialBackupEncryptionKey(
            seedHex: hex,
            network: network.rawValue
        )
    }
}
