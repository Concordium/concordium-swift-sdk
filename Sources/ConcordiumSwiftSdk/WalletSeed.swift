import ConcordiumWalletCrypto
import CryptoKit
import Foundation

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

/// Class for deterministically deriving cryptographic values related to credentials from a seed.
public class WalletSeed {
    private let hex: String
    private let network: Network

    public init(hex: String, network: Network) {
        self.hex = hex
        self.network = network
    }

    public func signingKey(of credential: AccountCredentialCoordinates) throws -> String {
        try getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func publicKey(of credential: AccountCredentialCoordinates) throws -> String {
        try getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func id(of credential: AccountCredentialCoordinates, commitmentKey: String) throws -> String {
        try getCredentialId(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: credential.counter,
            commitmentKey: commitmentKey
        )
    }

    public func prfKey(of identity: IdentityCoordinates) throws -> String {
        try getPrfKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func credSec(of identity: IdentityCoordinates) throws -> String {
        try getIdCredSec(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func signatureBlindingRandomness(of identity: IdentityCoordinates) throws -> String {
        try getSignatureBlindingRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func attributeCommitmentRandomness(of credential: AccountCredentialCoordinates, attribute: UInt8) throws -> String {
        try getAttributeCommitmentRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter),
            attribute: attribute
        )
    }

    public func signingKey(of verifiableCredential: VerifiableCredentialCoordinates) throws -> String {
        try getVerifiableCredentialSigningKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func publicKey(of verifiableCredential: VerifiableCredentialCoordinates) throws -> String {
        try getVerifiableCredentialPublicKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func verifiableCredentialBackupEncryptionKey() throws -> String {
        try getVerifiableCredentialBackupEncryptionKey(
            seedHex: hex,
            network: network.rawValue
        )
    }
}

public enum AccountGenerationError: Error {
    case noCredentials
}

public class SeedBasedAccountGenerator {
    public let seed: WalletSeed
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
                    let keyHex = try seed.signingKey(of: cred)
                    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: keyHex))
                    return (CredentialIndex(idx), [KeyIndex(0): key])
                }
            )
        )
    }
}

public class SeedBasedIdentityRequestGenerator {
    private let seed: WalletSeed
    private let globalContext: GlobalContext

    public init(seed: WalletSeed, globalContext: GlobalContext) {
        self.seed = seed
        self.globalContext = globalContext
    }

    public func createRecoveryRequestJson(provider: IdentityProviderInfo, index: UInt32, time: Date) throws -> String {
        let identityCoordinates = IdentityCoordinates(providerIndex: provider.identity, index: index)
        let credSec = try seed.credSec(of: identityCoordinates)
        return try createIdentityRecoveryRequestJson(
            params: IdentityRecoveryRequestParameters(
                ipInfo: provider,
                globalContext: globalContext,
                timestamp: UInt64(time.timeIntervalSince1970),
                idCredSec: credSec
            )
        )
    }

    public func createIssuanceRequestJson(provider: IdentityProvider, index: UInt32, anonymityRevokerThreshold: UInt8) throws -> String {
        let identityCoordinates = IdentityCoordinates(providerIndex: provider.info.identity, index: index)
        let prfKey = try seed.prfKey(of: identityCoordinates)
        let credSec = try seed.credSec(of: identityCoordinates)
        let blindingRandomness = try seed.signatureBlindingRandomness(of: identityCoordinates)
        return try createIdentityIssuanceRequestJson(
            params: IdentityIssuanceRequestParameters(
                ipInfo: provider.info,
                globalContext: globalContext,
                arsInfos: provider.anonymityRevokers,
                arThreshold: anonymityRevokerThreshold,
                prfKey: prfKey,
                idCredSec: credSec,
                blindingRandomness: blindingRandomness
            )
        )
    }
}

public class SeedBasedCredentialGenerator {
    private let seed: WalletSeed
    private let globalContext: GlobalContext

    public init(seed: WalletSeed, globalContext: GlobalContext) {
        self.seed = seed
        self.globalContext = globalContext
    }

    public func createCredential(
        coordinates: AccountCredentialCoordinates, // TODO: shouldn't identity know its own indexes?
        identity: IdentityObject,
        provider: IdentityProvider,
        revealedAttributes: [UInt8] = [],
        threshold: SignatureThreshold
    ) throws -> UnsignedCredentialResult {
        // TODO: Must provide exactly the IP's ARs?
        let anonymityRevokers = provider.anonymityRevokers
        let idCredSec = try seed.credSec(of: coordinates.identity)
        let prfKey = try seed.prfKey(of: coordinates.identity)
        let blindingRandomness = try seed.signatureBlindingRandomness(of: coordinates.identity)
        let attributeRandomness = try AttributeType.allCases.reduce(into: [:]) { res, attr in
            res["\(attr)"] = try seed.attributeCommitmentRandomness(of: coordinates, attribute: attr.rawValue)
        }
        let key = try [KeyIndex(0): seed.publicKey(of: coordinates)]
        let credentialPublicKeys = CredentialPublicKeys(keys: key, threshold: threshold)
        return try createUnsignedCredential(
            params: UnsignedCredentialParameters(
                ipInfo: provider.info,
                globalContext: globalContext,
                arsInfos: anonymityRevokers,
                idObject: identity,
                revealedAttributes: revealedAttributes,
                credNumber: coordinates.counter,
                idCredSec: idCredSec,
                prfKey: prfKey,
                blindingRandomness: blindingRandomness,
                attributeRandomness: attributeRandomness,
                credentialPublicKeys: credentialPublicKeys
            )
        )
    }
}
