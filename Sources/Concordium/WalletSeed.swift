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
    private let seed: Data
    private let network: Network

    public init(seed: Data, network: Network) {
        self.seed = seed
        self.network = network
    }

    public init(seedHex: String, network: Network) throws {
        seed = try Data(hex: seedHex)
        self.network = network
    }

    public func credSec(identityIndexes: IdentitySeedIndexes) throws -> Data {
        try identityCredSec(
            seed: seed,
            network: network.rawValue,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func prfKey(identityIndexes: IdentitySeedIndexes) throws -> Data {
        try identityPrfKey(
            seed: seed,
            network: network.rawValue,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func signatureBlindingRandomness(identityIndexes: IdentitySeedIndexes) throws -> Data {
        try identityAttributesSignatureBlindingRandomness(
            seed: seed,
            network: network.rawValue,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    public func signingKey(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> Data {
        try accountCredentialSigningKey(
            seed: seed,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    public func publicKey(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> Data {
        try accountCredentialPublicKey(
            seed: seed,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    public func id(accountCredentialIndexes: AccountCredentialSeedIndexes, commitmentKey: Data) throws -> Data {
        try accountCredentialId(
            seed: seed,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            commitmentKey: commitmentKey
        )
    }

    public func attributeCommitmentRandomness(accountCredentialIndexes: AccountCredentialSeedIndexes, attribute: UInt8) throws -> Data {
        try accountCredentialAttributeCommitmentRandomness(
            seed: seed,
            network: network.rawValue,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            attribute: attribute
        )
    }

    public func signingKey(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes) throws -> Data {
        try verifiableCredentialSigningKey(
            seed: seed,
            network: network.rawValue,
            issuerIndex: verifiableCredentialIndexes.issuer.index,
            issuerSubindex: verifiableCredentialIndexes.issuer.subindex,
            verifiableCredentialIndex: verifiableCredentialIndexes.index
        )
    }

    public func publicKey(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes) throws -> Data {
        try verifiableCredentialPublicKey(
            seed: seed,
            network: network.rawValue,
            issuerIndex: verifiableCredentialIndexes.issuer.index,
            issuerSubindex: verifiableCredentialIndexes.issuer.subindex,
            verifiableCredentialIndex: verifiableCredentialIndexes.index
        )
    }

    public func verifiableCredentialBackupEncryptionKey() throws -> Data {
        try ConcordiumWalletCrypto.verifiableCredentialBackupEncryptionKey(
            seed: seed,
            network: network.rawValue
        )
    }
}

public enum AccountDerivationError: Error {
    case noCredentials
}

public class SeedBasedAccountDerivation {
    public let seed: WalletSeed
    private let cryptoParams: CryptographicParameters

    public init(seed: WalletSeed, cryptoParams: CryptographicParameters) {
        self.seed = seed
        self.cryptoParams = cryptoParams
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
        let idCredSec = try seed.credSec(identityIndexes: seedIndexes.identity)
        let prfKey = try seed.prfKey(identityIndexes: seedIndexes.identity)
        let blindingRandomness = try seed.signatureBlindingRandomness(identityIndexes: seedIndexes.identity)
        let attributeRandomness = try AttributeTag.allCases.reduce(into: [:]) { res, attr in
            res["\(attr)"] = try seed.attributeCommitmentRandomness(
                accountCredentialIndexes: seedIndexes,
                attribute: attr.rawValue
            )
        }
        let key = try seed.publicKey(accountCredentialIndexes: seedIndexes)
        let credentialPublicKeys = try CredentialPublicKeys(
            keys: [KeyIndex(0): VerifyKey(ed25519Key: key)],
            threshold: threshold
        )
        let res = try accountCredential(
            params: AccountCredentialParameters(
                ipInfo: provider.info,
                globalContext: cryptoParams,
                arsInfos: anonymityRevokers,
                idObject: identity,
                revealedAttributes: revealedAttributes,
                credNumber: seedIndexes.counter,
                idCredSec: idCredSec,
                prfKey: prfKey,
                blindingRandomness: blindingRandomness,
                attributeRandomness: attributeRandomness,
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
        let id = try seed.id(accountCredentialIndexes: firstCredential, commitmentKey: cryptoParams.onChainCommitmentKey)
        let hash = SHA256.hash(data: id)
        return AccountAddress(Data(hash))
    }

    public func deriveKeys(credentials: [AccountCredentialSeedIndexes]) throws -> AccountKeysCurve25519 {
        try AccountKeysCurve25519(
            Dictionary(
                uniqueKeysWithValues: credentials.enumerated().map { idx, cred in
                    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed.signingKey(accountCredentialIndexes: cred))
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
        let idCredSec = try seed.credSec(identityIndexes: identityIdxs)
        return try identityRecoveryRequestJson(
            params: IdentityRecoveryRequestParameters(
                ipInfo: provider,
                globalContext: cryptoParams,
                timestamp: UInt64(time.timeIntervalSince1970),
                idCredSec: idCredSec
            )
        )
    }

    public func issuanceRequestJSON(provider: IdentityProvider, index: IdentityIndex, anonymityRevocationThreshold: RevocationThreshold) throws -> String {
        let identityIdxs = IdentitySeedIndexes(providerID: provider.info.identity, index: index)
        let prfKey = try seed.prfKey(identityIndexes: identityIdxs)
        let credSec = try seed.credSec(identityIndexes: identityIdxs)
        let blindingRandomness = try seed.signatureBlindingRandomness(identityIndexes: identityIdxs)
        return try identityIssuanceRequestJson(
            params: IdentityIssuanceRequestParameters(
                ipInfo: provider.info,
                globalContext: cryptoParams,
                arsInfos: provider.anonymityRevokers,
                arThreshold: anonymityRevocationThreshold,
                prfKey: prfKey,
                idCredSec: credSec,
                blindingRandomness: blindingRandomness
            )
        )
    }
}
