import ConcordiumWalletCrypto
import Foundation

/// Class for deterministically deriving cryptographic values related to credentials from a seed.
public class WalletSeed {
    private let hex: String
    private let network: Network

    public init(hex: String, network: Network) {
        self.hex = hex
        self.network = network
    }

    public func signingKey(of credential: AccountCredentialCoordinates) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func publicKey(of credential: AccountCredentialCoordinates) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func id(of credential: AccountCredentialCoordinates, commitmentKey: String) throws -> String {
        try ConcordiumWalletCrypto.getCredentialId(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: credential.counter,
            commitmentKey: commitmentKey
        )
    }

    public func prfKey(of identity: IdentityCoordinates) throws -> String {
        try ConcordiumWalletCrypto.getPrfKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func credSec(of identity: IdentityCoordinates) throws -> String {
        try ConcordiumWalletCrypto.getIdCredSec(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func signatureBlindingRandomness(of identity: IdentityCoordinates) throws -> String {
        try ConcordiumWalletCrypto.getSignatureBlindingRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func attributeCommitmentRandomness(of credential: AccountCredentialCoordinates, attribute: UInt8) throws -> String {
        try ConcordiumWalletCrypto.getAttributeCommitmentRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter),
            attribute: attribute
        )
    }

    public func signingKey(of verifiableCredential: VerifiableCredentialCoordinates) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialSigningKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func publicKey(of verifiableCredential: VerifiableCredentialCoordinates) throws -> String {
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

public enum Network: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

public struct IdentityCoordinates {
    public var providerIndex: UInt32
    public var index: UInt32

    public init(providerIndex: UInt32, index: UInt32) {
        self.providerIndex = providerIndex
        self.index = index
    }
}

public struct AccountCredentialCoordinates {
    public var identity: IdentityCoordinates
    public var counter: UInt8

    public init(identity: IdentityCoordinates, counter: UInt8) {
        self.identity = identity
        self.counter = counter
    }
}

public struct IssuerCoordinates {
    public var index: UInt64
    public var subindex: UInt64

    public init(index: UInt64, subindex: UInt64) {
        self.index = index
        self.subindex = subindex
    }
}

public struct VerifiableCredentialCoordinates {
    public var issuer: IssuerCoordinates
    public var index: UInt32

    public init(issuer: IssuerCoordinates, index: UInt32) {
        self.issuer = issuer
        self.index = index
    }
}
