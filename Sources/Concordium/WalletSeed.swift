import ConcordiumWalletCrypto
import CryptoKit
import Foundation

public typealias IdentityIndex = UInt32
public typealias CredentialCounter = UInt8
public typealias IssuerIndex = UInt64
public typealias IssuerSubindex = UInt64
public typealias VerifiableCredentialIndex = UInt32

public enum Network: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

public struct IdentitySeedIndexes {
    public var providerID: IdentityProviderID
    public var index: IdentityIndex

    public init(providerID: IdentityProviderID, index: IdentityIndex) {
        self.providerID = providerID
        self.index = index
    }
}

public struct AccountCredentialSeedIndexes {
    public var identity: IdentitySeedIndexes
    public var counter: CredentialCounter

    public init(identity: IdentitySeedIndexes, counter: CredentialCounter) {
        self.identity = identity
        self.counter = counter
    }
}

public struct IssuerSeedIndexes {
    public var index: IssuerIndex
    public var subindex: IssuerSubindex

    public init(index: IssuerIndex, subindex: IssuerSubindex) {
        self.index = index
        self.subindex = subindex
    }
}

public struct VerifiableCredentialSeedIndexes {
    public var issuer: IssuerSeedIndexes
    public var index: VerifiableCredentialIndex

    public init(issuer: IssuerSeedIndexes, index: VerifiableCredentialIndex) {
        self.issuer = issuer
        self.index = index
    }
}

/// Class for deterministically deriving cryptographic values related to credentials from a seed.
public class WalletSeed {
    private let seedHex: String
    private let network: Network

    public init(seedHex: String, network: Network) {
        self.seedHex = seedHex
        self.network = network
    }

    public func credSecHex(identityIndexes: IdentitySeedIndexes) throws -> String {
        try identityCredSecHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func prfKeyHex(identityIndexes: IdentitySeedIndexes) throws -> String {
        try identityPrfKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func signatureBlindingRandomnessHex(identityIndexes: IdentitySeedIndexes) throws -> String {
        try identityAttributesSignatureBlindingRandomnessHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func signingKeyHex(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> String {
        try accountCredentialSigningKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    public func publicKeyHex(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> String {
        try accountCredentialPublicKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    public func idHex(accountCredentialIndexes: AccountCredentialSeedIndexes, commitmentKey: String) throws -> String {
        try accountCredentialIdHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            commitmentKey: commitmentKey
        )
    }

    public func attributeCommitmentRandomnessHex(accountCredentialIndexes: AccountCredentialSeedIndexes, attribute: UInt8) throws -> String {
        try accountCredentialAttributeCommitmentRandomnessHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            attribute: attribute
        )
    }

    public func signingKeyHex(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes) throws -> String {
        try verifiableCredentialSigningKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            issuerIndex: verifiableCredentialIndexes.issuer.index,
            issuerSubindex: verifiableCredentialIndexes.issuer.subindex,
            verifiableCredentialIndex: verifiableCredentialIndexes.index
        )
    }

    public func publicKeyHex(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes) throws -> String {
        try verifiableCredentialPublicKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            issuerIndex: verifiableCredentialIndexes.issuer.index,
            issuerSubindex: verifiableCredentialIndexes.issuer.subindex,
            verifiableCredentialIndex: verifiableCredentialIndexes.index
        )
    }

    public func verifiableCredentialBackupEncryptionKeyHex() throws -> String {
        try ConcordiumWalletCrypto.verifiableCredentialBackupEncryptionKeyHex(
            seedHex: seedHex,
            network: network.rawValue
        )
    }
}
