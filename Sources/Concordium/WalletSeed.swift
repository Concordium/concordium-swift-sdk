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
        seedIndexes: AccountCredentialSeedIndexes, // TODO: shouldn't identity know its own indexes?
        identity: IdentityObject,
        provider: IdentityProvider,
        revealedAttributes: [UInt8] = [],
        threshold: SignatureThreshold
    ) throws -> AccountCredential {
        // TODO: Must provide exactly the IP's ARs?
        let anonymityRevokers = provider.anonymityRevokers
        let idCredSecHex = try seed.credSecHex(identityIndexes: seedIndexes.identity)
        let prfKeyHex = try seed.prfKeyHex(identityIndexes: seedIndexes.identity)
        let blindingRandomnessHex = try seed.signatureBlindingRandomnessHex(identityIndexes: seedIndexes.identity)
        let attributeRandomnessHex = try AttributeType.allCases.reduce(into: [:]) { res, attr in
            res["\(attr)"] = try seed.attributeCommitmentRandomnessHex(
                accountCredentialIndexes: seedIndexes,
                attribute: attr.rawValue
            )
        }
        let keyHex = try seed.publicKeyHex(accountCredentialIndexes: seedIndexes)
        let credentialPublicKeys = CredentialPublicKeys(
            keys: [KeyIndex(0): VerifyKey(ed25519KeyHex: keyHex)],
            threshold: threshold
        )
        let res = try ConcordiumWalletCrypto.accountCredential(
            params: AccountCredentialParameters(
                ipInfo: provider.info,
                globalContext: globalContext,
                arsInfos: anonymityRevokers,
                idObject: identity,
                revealedAttributes: revealedAttributes,
                credNumber: seedIndexes.counter,
                idCredSecHex: idCredSecHex,
                prfKeyHex: prfKeyHex,
                blindingRandomnessHex: blindingRandomnessHex,
                attributeRandomnessHex: attributeRandomnessHex,
                credentialPublicKeys: credentialPublicKeys
            )
        )
        return res.credential
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
        let id = try seed.idHex(accountCredentialIndexes: firstCredential, commitmentKey: globalContext.onChainCommitmentKeyHex)
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
    private let globalContext: GlobalContext

    public init(seed: WalletSeed, globalContext: GlobalContext) {
        self.seed = seed
        self.globalContext = globalContext
    }

    public func recoveryRequestJson(provider: IdentityProviderInfo, index: IdentityIndex, time: Date) throws -> String {
        let identityIdxs = IdentitySeedIndexes(providerID: provider.identity, index: index)
        let idCredSec = try seed.credSecHex(identityIndexes: identityIdxs)
        return try identityRecoveryRequestJson(
            params: IdentityRecoveryRequestParameters(
                ipInfo: provider,
                globalContext: globalContext,
                timestamp: UInt64(time.timeIntervalSince1970),
                idCredSecHex: idCredSec
            )
        )
    }

    public func issuanceRequestJson(provider: IdentityProvider, index: IdentityIndex, anonymityRevokerThreshold: RevocationThreshold) throws -> String {
        let identityIdxs = IdentitySeedIndexes(providerID: provider.info.identity, index: index)
        let prfKeyHex = try seed.prfKeyHex(identityIndexes: identityIdxs)
        let credSecHex = try seed.credSecHex(identityIndexes: identityIdxs)
        let blindingRandomnessHex = try seed.signatureBlindingRandomnessHex(identityIndexes: identityIdxs)
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
