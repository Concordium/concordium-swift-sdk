import ConcordiumWalletCrypto
import CryptoKit
import Foundation

public enum WalletError: Error {
    case mismatchingKeys
    case noCredentials
    case credentialCounterOutOfRange
}

public enum Network: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

public protocol WalletProtocol {
    associatedtype Credential
    func sign(_ message: Data, with account: Account<Credential>) throws -> [CredentialIndex: [KeyIndex: Data]]
}

public struct Identity {
    public var providerIndex: UInt32
    public var index: UInt32

    public init(providerIndex: UInt32, index: UInt32) {
        self.providerIndex = providerIndex
        self.index = index
    }
}

public struct IdentityCredential {
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

public struct Account<Credential> {
    public var address: AccountAddress
    public var credentials: [Credential]

    public init(address: AccountAddress, credentials: [Credential]) {
        self.address = address
        self.credentials = credentials
    }
}

public class SeedBasedWallet: WalletProtocol {
    public typealias Credential = IdentityCredential

    let seed: WalletSeed

    public init(seed: WalletSeed) {
        self.seed = seed
    }

    public func generateAccount(credentials: [Credential], commitmentKey: String) throws -> Account<IdentityCredential> {
        guard let firstCred = credentials.first else {
            throw WalletError.noCredentials
        }
        let firstCredId = try seed.id(of: firstCred, commitmentKey: commitmentKey)
        let addr = try SHA256.hash(data: Data(hex: firstCredId))
        return Account(address: .init(Data(addr)), credentials: credentials)
    }

    public func sign(_ message: Data, with account: Account<Credential>) throws -> [CredentialIndex: [KeyIndex: Data]] {
        try Dictionary(
            uniqueKeysWithValues: account.credentials.enumerated().map { idx, cred in
                try (CredentialIndex(idx), sign(message, with: cred))
            }
        )
    }

    public func sign(_ message: Data, with credential: Credential) throws -> [KeyIndex: Data] {
        let keyHex = try seed.signingKey(of: credential)
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: keyHex))
        return try [0: key.signature(for: message)]
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

    public func signingKey(of credential: IdentityCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func publicKey(of credential: IdentityCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func id(of credential: IdentityCredential, commitmentKey: String) throws -> String {
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

    public func attributeCommitmentRandomness(of credential: IdentityCredential, attribute: UInt8) throws -> String {
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
