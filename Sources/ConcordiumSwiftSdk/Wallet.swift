import ConcordiumWalletCrypto
import CryptoKit
import Foundation

public enum WalletError: Error {
    case noCredentials
}

public enum Network: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

public class AccountKeys {
    let keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]

    public init(_ keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]) {
        self.keys = keys
    }

    public var keyCount: Int {
        keys.reduce(0) { acc, cred in acc + cred.value.count }
    }

    public func sign(_ message: Data) throws -> [CredentialIndex: [KeyIndex: Data]] {
        try keys.mapValues {
            try $0.mapValues {
                try $0.signature(for: message)
            }
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

public struct SeedBasedAccountCredential {
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

public class WalletAccount {
    public let address: AccountAddress
    public let keys: AccountKeys

    public init(address: AccountAddress, keys: AccountKeys) {
        self.address = address
        self.keys = keys
    }
}

public protocol WalletProtocol {
    func lookup(address: AccountAddress) -> WalletAccount?
}

public class SimpleWallet: WalletProtocol {
    private var accounts: [AccountAddress: WalletAccount]

    public init(accounts: [AccountAddress: WalletAccount] = [:]) {
        self.accounts = accounts
    }

    public func insert(account: WalletAccount) {
        accounts[account.address] = account
    }

    public func remove(address: AccountAddress) {
        accounts[address] = nil
    }

    public func lookup(address: AccountAddress) -> WalletAccount? {
        accounts[address]
    }
}

public class SeedBasedAccountGenerator {
    let seed: WalletSeed
    let commitmentKey: String

    public init(seed: WalletSeed, commitmentKey: String) {
        self.seed = seed
        self.commitmentKey = commitmentKey
    }

    public func generateAccount(credentials: [SeedBasedAccountCredential]) throws -> WalletAccount {
        guard let firstCred = credentials.first else {
            throw WalletError.noCredentials
        }
        return try WalletAccount(
            address: generateAccountAddress(firstCredential: firstCred),
            keys: generateKeys(credentials: credentials)
        )
    }

    public func generateAccountAddress(firstCredential: SeedBasedAccountCredential) throws -> AccountAddress {
        let id = try seed.id(of: firstCredential, commitmentKey: commitmentKey)
        let hash = try SHA256.hash(data: Data(hex: id))
        return AccountAddress(Data(hash))
    }

    public func generateKeys(credentials: [SeedBasedAccountCredential]) throws -> AccountKeys {
        try AccountKeys(
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

/// Class for deriving cryptographic values related to credentials.
public class WalletSeed {
    let hex: String
    let network: Network

    public init(hex: String, network: Network) {
        self.hex = hex
        self.network = network
    }

    public func signingKey(of credential: SeedBasedAccountCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func publicKey(of credential: SeedBasedAccountCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func id(of credential: SeedBasedAccountCredential, commitmentKey: String) throws -> String {
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

    public func attributeCommitmentRandomness(of credential: SeedBasedAccountCredential, attribute: UInt8) throws -> String {
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
