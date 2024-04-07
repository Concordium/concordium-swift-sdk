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

public class SeedBasedIdentityObject {
    public var identity: IdentityObject
    public var indexes: IdentitySeedIndexes

    public init(identity: IdentityObject, indexes: IdentitySeedIndexes) {
        self.identity = identity
        self.indexes = indexes
    }
}

public class SeedBasedAccountCredential {
    public var credential: AccountCredential
    public var identity: SeedBasedIdentityObject
    public var credentialCounter: CredentialCounter

    public init(credential: AccountCredential, identity: SeedBasedIdentityObject, credentialCounter: CredentialCounter) {
        self.credential = credential
        self.identity = identity
        self.credentialCounter = credentialCounter
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
    public let network: Network

    public init(seedHex: String, network: Network) {
        self.seedHex = seedHex
        self.network = network
    }

    public func credSecHex(identityIndexes: IdentitySeedIndexes) throws -> String {
        try identityCredSecHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func prfKeyHex(identityIndexes: IdentitySeedIndexes) throws -> String {
        try identityPrfKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func signatureBlindingRandomnessHex(identityIndexes: IdentitySeedIndexes) throws -> String {
        try identityAttributesSignatureBlindingRandomnessHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func signingKeyHex(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> String {
        try accountCredentialSigningKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    public func publicKeyHex(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> String {
        try accountCredentialPublicKeyHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    public func idHex(accountCredentialIndexes: AccountCredentialSeedIndexes, commitmentKey: String) throws -> String {
        try accountCredentialIdHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            commitmentKey: commitmentKey
        )
    }

    public func attributeCommitmentRandomnessHex(accountCredentialIndexes: AccountCredentialSeedIndexes, attribute: UInt8) throws -> String {
        try accountCredentialAttributeCommitmentRandomnessHex(
            seedHex: seedHex,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
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

public enum AccountDerivationError: Error {
    case noCredentials
}

public class SeedBasedAccountDerivation {
    private let seed: WalletSeed
    private let cryptoParams: CryptographicParameters

    public init(seed: WalletSeed, cryptoParams: CryptographicParameters) {
        self.seed = seed
        self.cryptoParams = cryptoParams
    }

    public func deriveCredential(
        credentialCounter: CredentialCounter,
        identity: SeedBasedIdentityObject,
        provider: IdentityProvider,
        revealedAttributes: [UInt8] = [],
        threshold: SignatureThreshold
    ) throws -> SeedBasedAccountCredential {
        let seedIdxs = AccountCredentialSeedIndexes(identity: identity.indexes, counter: credentialCounter)
        // TODO: Must provide exactly the IP's ARs?
        let anonymityRevokers = provider.anonymityRevokers
        let idCredSecHex = try seed.credSecHex(identityIndexes: seedIdxs.identity)
        let prfKeyHex = try seed.prfKeyHex(identityIndexes: seedIdxs.identity)
        let blindingRandomnessHex = try seed.signatureBlindingRandomnessHex(identityIndexes: seedIdxs.identity)
        let attributeRandomnessHex = try AttributeTag.allCases.reduce(into: [:]) { res, attr in
            res["\(attr)"] = try seed.attributeCommitmentRandomnessHex(
                accountCredentialIndexes: seedIdxs,
                attribute: attr.rawValue
            )
        }
        let keyHex = try seed.publicKeyHex(accountCredentialIndexes: seedIdxs)
        let credPublicKeys = CredentialPublicKeys(
            keys: [KeyIndex(0): VerifyKey(ed25519KeyHex: keyHex)],
            threshold: threshold
        )
        let res = try accountCredential(
            params: AccountCredentialParameters(
                ipInfo: provider.info,
                globalContext: cryptoParams,
                arsInfos: anonymityRevokers,
                idObject: identity.identity,
                revealedAttributes: revealedAttributes,
                credNumber: seedIdxs.counter,
                idCredSecHex: idCredSecHex,
                prfKeyHex: prfKeyHex,
                blindingRandomnessHex: blindingRandomnessHex,
                attributeRandomnessHex: attributeRandomnessHex,
                credentialPublicKeys: credPublicKeys
            )
        )
        return SeedBasedAccountCredential(
            credential: res.credential,
            identity: identity,
            credentialCounter: credentialCounter
        )
    }

    public func deriveAccount(credentials: [AccountCredentialSeedIndexes]) throws -> Account {
        guard let firstCred = credentials.first else {
            throw AccountDerivationError.noCredentials
        }
        return try Account(
            address: deriveAccountAddress(firstCredential: firstCred),
            keys: deriveKeys(credentials: credentials)
        )
    }

    public func deriveAccountAddress(firstCredential: AccountCredentialSeedIndexes) throws -> AccountAddress {
        let id = try seed.idHex(
            accountCredentialIndexes: firstCredential,
            commitmentKey: cryptoParams.onChainCommitmentKeyHex
        )
        let hash = try SHA256.hash(data: Data(hex: id))
        return AccountAddress(Data(hash))
    }

    public func deriveKeys(credentials: [AccountCredentialSeedIndexes]) throws -> AccountKeysCurve25519 {
        try AccountKeysCurve25519(
            Dictionary(
                uniqueKeysWithValues: credentials.enumerated().map { idx, cred in
                    let keyHex = try seed.signingKeyHex(accountCredentialIndexes: cred)
                    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: keyHex))
                    return (CredentialIndex(idx), [KeyIndex(0): key])
                }
            )
        )
    }
}

public class SeedBasedIdentityRequestBuilder {
    private let seed: WalletSeed
    private let cryptoParams: CryptographicParameters

    public init(seed: WalletSeed, cryptoParams: CryptographicParameters) {
        self.seed = seed
        self.cryptoParams = cryptoParams
    }

    public func recoveryRequestJSON(provider: IdentityProviderInfo, index: IdentityIndex, time: Date) throws -> String {
        let identityIdxs = IdentitySeedIndexes(providerID: provider.identity, index: index)
        let idCredSec = try seed.credSecHex(identityIndexes: identityIdxs)
        return try identityRecoveryRequestJson(
            params: IdentityRecoveryRequestParameters(
                ipInfo: provider,
                globalContext: cryptoParams,
                timestamp: UInt64(time.timeIntervalSince1970),
                idCredSecHex: idCredSec
            )
        )
    }

    public func issuanceRequestJSON(provider: IdentityProvider, index: IdentityIndex, anonymityRevocationThreshold: RevocationThreshold) throws -> String {
        let identityIdxs = IdentitySeedIndexes(providerID: provider.info.identity, index: index)
        let prfKeyHex = try seed.prfKeyHex(identityIndexes: identityIdxs)
        let credSecHex = try seed.credSecHex(identityIndexes: identityIdxs)
        let blindingRandomnessHex = try seed.signatureBlindingRandomnessHex(identityIndexes: identityIdxs)
        return try identityIssuanceRequestJson(
            params: IdentityIssuanceRequestParameters(
                ipInfo: provider.info,
                globalContext: cryptoParams,
                arsInfos: provider.anonymityRevokers,
                arThreshold: anonymityRevocationThreshold,
                prfKeyHex: prfKeyHex,
                idCredSecHex: credSecHex,
                blindingRandomnessHex: blindingRandomnessHex
            )
        )
    }
}
