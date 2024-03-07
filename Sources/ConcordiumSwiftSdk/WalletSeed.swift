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
    private let seedHex: String
    private let network: Network

    public init(seedHex: String, network: Network) {
        self.seedHex = seedHex
        self.network = network
    }

    public func signingKeyHex(of credential: AccountCredentialCoordinates) throws -> String {
        try accountCredentialSigningKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func publicKeyHex(of credential: AccountCredentialCoordinates) throws -> String {
        try accountCredentialPublicKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    public func idHex(of credential: AccountCredentialCoordinates, commitmentKey: String) throws -> String {
        try accountCredentialIdHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: credential.counter,
            commitmentKey: commitmentKey
        )
    }

    public func prfKeyHex(of identity: IdentityCoordinates) throws -> String {
        try ConcordiumWalletCrypto.prfKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func idCredSecHex(of identity: IdentityCoordinates) throws -> String {
        try ConcordiumWalletCrypto.idCredSecHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func signatureBlindingRandomnessHex(of identity: IdentityCoordinates) throws -> String {
        try ConcordiumWalletCrypto.signatureBlindingRandomnessHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    public func attributeCommitmentRandomnessHex(of credential: AccountCredentialCoordinates, attribute: UInt8) throws -> String {
        try ConcordiumWalletCrypto.attributeCommitmentRandomnessHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter),
            attribute: attribute
        )
    }

    public func signingKeyHex(of verifiableCredential: VerifiableCredentialCoordinates) throws -> String {
        try verifiableCredentialSigningKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func publicKeyHex(of verifiableCredential: VerifiableCredentialCoordinates) throws -> String {
        try verifiableCredentialPublicKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    public func verifiableCredentialBackupEncryptionKeyHex() throws -> String {
        try ConcordiumWalletCrypto.verifiableCredentialBackupEncryptionKeyHex(
            seedHex: seedHex,
            network: network.rawValue
        )
    }
}

public enum AccountDerivationError: Error {
    case noCredentials
}

public class SeedBasedAccountDerivation {
    public let seed: WalletSeed
    private let globalContext: GlobalContext

    public init(seed: WalletSeed, globalContext: GlobalContext) {
        self.seed = seed
        self.globalContext = globalContext
    }

    public func deriveCredential(
        coordinates: AccountCredentialCoordinates, // TODO: shouldn't identity know its own coordinates?
        identity: IdentityObject,
        provider: IdentityProvider,
        revealedAttributes: [UInt8] = [],
        threshold: SignatureThreshold
    ) throws -> AccountCredential {
        // TODO: Must provide exactly the IP's ARs?
        let anonymityRevokers = provider.anonymityRevokers
        let idCredSecHex = try seed.idCredSecHex(of: coordinates.identity)
        let prfKeyHex = try seed.prfKeyHex(of: coordinates.identity)
        let blindingRandomnessHex = try seed.signatureBlindingRandomnessHex(of: coordinates.identity)
        let attributeRandomnessHex = try AttributeType.allCases.reduce(into: [:]) { res, attr in
            res["\(attr)"] = try seed.attributeCommitmentRandomnessHex(of: coordinates, attribute: attr.rawValue)
        }
        let keys_hex = try [KeyIndex(0): seed.publicKeyHex(of: coordinates)]
        let credentialPublicKeysHex = CredentialPublicKeysHex(keys: keys_hex, threshold: threshold)
        let res = try ConcordiumWalletCrypto.accountCredential(
            params: AccountCredentialParameters(
                ipInfo: provider.info,
                globalContext: globalContext,
                arsInfos: anonymityRevokers,
                idObject: identity,
                revealedAttributes: revealedAttributes,
                credNumber: coordinates.counter,
                idCredSecHex: idCredSecHex,
                prfKeyHex: prfKeyHex,
                blindingRandomnessHex: blindingRandomnessHex,
                attributeRandomnessHex: attributeRandomnessHex,
                credentialPublicKeysHex: credentialPublicKeysHex
            )
        )
        return res.credential
    }

    public func deriveAccount(credentials: [AccountCredentialCoordinates]) throws -> WalletAccount {
        guard let firstCred = credentials.first else {
            throw AccountDerivationError.noCredentials
        }
        return try WalletAccount(
            address: deriveAccountAddress(firstCredential: firstCred),
            keys: deriveKeys(credentials: credentials)
        )
    }

    public func deriveAccountAddress(firstCredential: AccountCredentialCoordinates) throws -> AccountAddress {
        let id = try seed.idHex(of: firstCredential, commitmentKey: globalContext.onChainCommitmentKeyHex)
        let hash = try SHA256.hash(data: Data(hex: id))
        return AccountAddress(Data(hash))
    }

    public func deriveKeys(credentials: [AccountCredentialCoordinates]) throws -> AccountKeysCurve25519 {
        try AccountKeysCurve25519(
            Dictionary(
                uniqueKeysWithValues: credentials.enumerated().map { idx, cred in
                    let keyHex = try seed.signingKeyHex(of: cred)
                    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: keyHex))
                    return (CredentialIndex(idx), [KeyIndex(0): key])
                }
            )
        )
    }
}

public class SeedBasedIdentityRequestBuilder {
    private let seed: WalletSeed
    private let globalContext: GlobalContext

    public init(seed: WalletSeed, globalContext: GlobalContext) {
        self.seed = seed
        self.globalContext = globalContext
    }

    public func recoveryRequestJson(provider: IdentityProviderInfo, index: UInt32, time: Date) throws -> String {
        let identityCoordinates = IdentityCoordinates(providerIndex: provider.identity, index: index)
        let idCredSec = try seed.idCredSecHex(of: identityCoordinates)
        return try identityRecoveryRequestJson(
            params: IdentityRecoveryRequestParameters(
                ipInfo: provider,
                globalContext: globalContext,
                timestamp: UInt64(time.timeIntervalSince1970),
                idCredSecHex: idCredSec
            )
        )
    }

    public func issuanceRequestJson(provider: IdentityProvider, index: UInt32, anonymityRevokerThreshold: UInt8) throws -> String {
        let identityCoordinates = IdentityCoordinates(providerIndex: provider.info.identity, index: index)
        let prfKeyHex = try seed.prfKeyHex(of: identityCoordinates)
        let credSecHex = try seed.idCredSecHex(of: identityCoordinates)
        let blindingRandomnessHex = try seed.signatureBlindingRandomnessHex(of: identityCoordinates)
        return try identityIssuanceRequestJson(
            params: IdentityIssuanceRequestParameters(
                ipInfo: provider.info,
                globalContext: globalContext,
                arsInfos: provider.anonymityRevokers,
                arThreshold: anonymityRevokerThreshold,
                prfKeyHex: prfKeyHex,
                idCredSecHex: credSecHex,
                blindingRandomnessHex: blindingRandomnessHex
            )
        )
    }
}
