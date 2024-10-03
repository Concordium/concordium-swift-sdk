import ConcordiumWalletCrypto
import CryptoKit
import Foundation

/// Represents an index for an identity under an identity provider
public typealias IdentityIndex = UInt32
/// Represents an index for a credential on an identity
public typealias CredentialCounter = UInt8
/// Represents an index Web3 ID issuer
public typealias IssuerIndex = UInt64
/// Represents an subindex Web3 ID issuer under an `IssuerIndex`
public typealias IssuerSubindex = UInt64
/// Represents an index for a Web3 ID credential under the indices specifying a Web3 ID issuer
public typealias VerifiableCredentialIndex = UInt32

/// Represents the seed indices for deriving cryptographic values for a specific identity
public struct IdentitySeedIndexes {
    /// The identity provider index, specifying the innermost part of the derivation path
    public var providerID: IdentityProviderID
    /// The identity index, specifying the second part of the derivation path
    public var index: IdentityIndex

    public init(providerID: IdentityProviderID, index: IdentityIndex) {
        self.providerID = providerID
        self.index = index
    }
}

/// Represents the seed indices for deriving cryptographic values for a specific credential for an identity
public struct AccountCredentialSeedIndexes {
    /// Specifies the identity the credential values are derived for (first + second part of the derivation path)
    public var identity: IdentitySeedIndexes
    /// The credential index, specifying the third part of the derivation path
    public var counter: CredentialCounter

    public init(identity: IdentitySeedIndexes, counter: CredentialCounter) {
        self.identity = identity
        self.counter = counter
    }
}

/// Represents the seed indices for deriving cryptographic values for a specific web3 ID issuer
public struct IssuerSeedIndexes {
    /// The (smart contract) index, specifying the innermost part of the derivation path
    public var index: IssuerIndex
    /// The (smart contract) subindex, specifying the second part of the derivation path
    public var subindex: IssuerSubindex

    /// Initialize from a contract address
    public init(contractAddress: ContractAddress) {
        self = .init(index: contractAddress.index, subindex: contractAddress.subindex)
    }

    public init(index: IssuerIndex, subindex: IssuerSubindex) {
        self.index = index
        self.subindex = subindex
    }
}

/// Represents the seed indices for deriving cryptographic values for a specific web3 ID credential
public struct VerifiableCredentialSeedIndexes {
    /// Specifies the issuer the credential values are derived for (first + second part of the derivation path)
    public var issuer: IssuerSeedIndexes
    /// The credential index for the specific issuer, specifying the third part of the derivation path
    public var index: VerifiableCredentialIndex

    /// Initialize from a contract address + credential index
    public init(contractAddress: ContractAddress, index: VerifiableCredentialIndex) {
        self.issuer = .init(contractAddress: contractAddress)
        self.index = index
    }

    public init(issuer: IssuerSeedIndexes, index: VerifiableCredentialIndex) {
        self.issuer = issuer
        self.index = index
    }
}

/// Class for deterministically deriving cryptographic values related to credentials from a seed.
public class WalletSeed {
    let seed: Data
    let network: Network

    public init(seed: Data, network: Network) {
        self.seed = seed
        self.network = network
    }

    public init(seedHex: String, network: Network) throws {
        seed = try Data(hex: seedHex)
        self.network = network
    }

    /// Compute the IDCredSec for the identity indices
    public func credSec(identityIndexes: IdentitySeedIndexes) throws -> Data {
        try identityCredSec(
            seed: seed,
            network: network,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    /// Compute the PRF key for the identity indices
    public func prfKey(identityIndexes: IdentitySeedIndexes) throws -> Data {
        try identityPrfKey(
            seed: seed,
            network: network,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    /// Compute the signature blinding randomnessfor the identity indices.
    public func signatureBlindingRandomness(identityIndexes: IdentitySeedIndexes) throws -> Data {
        try identityAttributesSignatureBlindingRandomness(
            seed: seed,
            network: network,
            identityProviderId: identityIndexes.providerID,
            identityIndex: identityIndexes.index
        )
    }

    /// Compute the signing key for the account credential corresponding to the account credential indices
    public func signingKey(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> Data {
        try accountCredentialSigningKey(
            seed: seed,
            network: network,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    /// Compute the public key for the account credential corresponding to the account credential indices
    public func publicKey(accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> Data {
        try accountCredentialPublicKey(
            seed: seed,
            network: network,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter
        )
    }

    /// Compute the encryption keys for the credential corresponding to the account credential indices with the chain context
    public func encryptionKeys(globalContext: CryptographicParameters, accountCredentialIndexes: AccountCredentialSeedIndexes) throws -> EncryptionKeys {
        let prfKey = try prfKey(identityIndexes: accountCredentialIndexes.identity)
        return try getEncryptionKeys(globalContext: globalContext, prfKey: prfKey, credentialIndex: accountCredentialIndexes.counter)
    }

    /// Compute the account credential registration ID for the credential corresponding to the account credential indices
    public func id(accountCredentialIndexes: AccountCredentialSeedIndexes, commitmentKey: Data) throws -> CredentialRegistrationID {
        let data = try accountCredentialId(
            seed: seed,
            network: network,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            commitmentKey: commitmentKey
        )
        return try CredentialRegistrationID(data)
    }

    /// Compute the attribute commitment randomness for the identity attribute corresponding to the numeric value supplied.
    func attributeCommitmentRandomness(accountCredentialIndexes: AccountCredentialSeedIndexes, attribute: UInt8) throws -> Data {
        try accountCredentialAttributeCommitmentRandomness(
            seed: seed,
            network: network,
            identityProviderId: accountCredentialIndexes.identity.providerID,
            identityIndex: accountCredentialIndexes.identity.index,
            credentialCounter: accountCredentialIndexes.counter,
            attribute: attribute
        )
    }

    /// Compute the attribute commitment randomness for the identity attribute
    func attributeCommitmentRandomness(accountCredentialIndexes: AccountCredentialSeedIndexes, attribute: AttributeTag) throws -> Data {
        try attributeCommitmentRandomness(accountCredentialIndexes: accountCredentialIndexes, attribute: attribute.rawValue)
    }

    /// Compute the attribute commitment randomness for the list of identity attributes
    public func attributeCommitmentRandomness(accountCredentialIndexes: AccountCredentialSeedIndexes, attributes: [AttributeTag]) throws -> [AttributeTag: Data] {
        try attributes.reduce(into: [:]) { acc, attr in
            acc[attr] = try attributeCommitmentRandomness(accountCredentialIndexes: accountCredentialIndexes, attribute: attr.rawValue)
        }
    }

    /// Compute the signing key for the Web3 ID credential corresponding to the credential indices
    public func signingKey(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes) throws -> Data {
        try verifiableCredentialSigningKey(
            seed: seed,
            network: network,
            issuerIndex: verifiableCredentialIndexes.issuer.index,
            issuerSubindex: verifiableCredentialIndexes.issuer.subindex,
            verifiableCredentialIndex: verifiableCredentialIndexes.index
        )
    }

    /// Compute the public key for the Web3 ID credential corresponding to the credential indices
    public func publicKey(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes) throws -> Data {
        try verifiableCredentialPublicKey(
            seed: seed,
            network: network,
            issuerIndex: verifiableCredentialIndexes.issuer.index,
            issuerSubindex: verifiableCredentialIndexes.issuer.subindex,
            verifiableCredentialIndex: verifiableCredentialIndexes.index
        )
    }

    /// Compute the verifiable credential backup key for the wallet seed
    public func verifiableCredentialBackupEncryptionKey() throws -> Data {
        try ConcordiumWalletCrypto.verifiableCredentialBackupEncryptionKey(
            seed: seed,
            network: network
        )
    }
}

public enum AccountDerivationError: Error {
    case noCredentials
}

/// A collection of functionality for account derivation for a wallet seed and a set of cryptographic parameters
public class SeedBasedAccountDerivation {
    /// The wallet seed
    public let seed: WalletSeed
    /// The cryptographic parameters of the chain
    private let cryptoParams: CryptographicParameters

    public init(seed: WalletSeed, cryptoParams: CryptographicParameters) {
        self.seed = seed
        self.cryptoParams = cryptoParams
    }

    /// Derive an account credential and the corresponding randomness values for the specified identity object
    /// - Parameters:
    ///   - seedIndexes: The account credential index to derive credentials for
    ///   - identity: The identity object corresponding to the identity specified in the credential indices
    ///   - provider: The identity provider data corresponding to the identity provider specified in the credential indices
    ///   - revealedAttributes: A set of attributes to reveal for the credential. Defaults to `[]`
    ///   - threshold: The minimum number of signatures on a credential that need to sign any transaction coming from an associated account. Defaults to `1`
    public func deriveCredential(
        seedIndexes: AccountCredentialSeedIndexes,
        identity: IdentityObject,
        provider: IdentityProvider,
        revealedAttributes: [AttributeTag] = [],
        threshold: SignatureThreshold = 1
    ) throws -> AccountCredentialWithRandomness {
        let anonymityRevokers = provider.anonymityRevokers
        let idCredSec = try seed.credSec(identityIndexes: seedIndexes.identity)
        let prfKey = try seed.prfKey(identityIndexes: seedIndexes.identity)
        let blindingRandomness = try seed.signatureBlindingRandomness(identityIndexes: seedIndexes.identity)
        let attributeRandomness = try AttributeTag.allCases.reduce(into: [:]) { res, attr in
            res[attr] = try seed.attributeCommitmentRandomness(
                accountCredentialIndexes: seedIndexes,
                attribute: attr.rawValue
            )
        }
        let key = try seed.publicKey(accountCredentialIndexes: seedIndexes)
        let credentialPublicKeys = try CredentialPublicKeys(
            keys: [KeyIndex(0): VerifyKey(ed25519Key: key)],
            threshold: threshold
        )
        return try accountCredential(
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
    }

    /// Derive an account an account from the list of account credential indices, using the first credential to derive the account address and all credentials
    /// for corresponding signing keys
    public func deriveAccount(credentials: [AccountCredentialSeedIndexes]) throws -> Account {
        guard let firstCred = credentials.first else {
            throw AccountDerivationError.noCredentials
        }
        return try Account(
            address: deriveAccountAddress(firstCredential: firstCred),
            keys: deriveKeys(credentials: credentials)
        )
    }

    /// Derive an account address for the account credential indices
    public func deriveAccountAddress(firstCredential: AccountCredentialSeedIndexes) throws -> AccountAddress {
        let id = try seed.id(accountCredentialIndexes: firstCredential, commitmentKey: cryptoParams.onChainCommitmentKey)
        return id.accountAddress
    }

    /// Derive the signing keys corresponding to the list of account credential indices.
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

/// Can be used to construct requests to identity providers
public class SeedBasedIdentityRequestBuilder {
    private let seed: WalletSeed
    private let cryptoParams: CryptographicParameters

    public init(seed: WalletSeed, cryptoParams: CryptographicParameters) {
        self.seed = seed
        self.cryptoParams = cryptoParams
    }

    /// Construct a recovery request for the identity provider and identity
    /// - Parameters:
    ///   - provider: the identity provider to construct the request for
    ///   - index: the identity index to use
    ///   - time: the timestamp of the recovery. Defaults to `Date.now` 
    public func recoveryRequestJSON(provider: IdentityProviderInfo, index: IdentityIndex, time: Date = Date.init(timeIntervalSinceNow: 0)) throws -> String {
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

    /// Construct an identity issuance request for the given identity provider
    /// - Parameters:
    ///   - provider: the identity provider to construct the request for
    ///   - index: the identity index to use
    ///   - anonymityRevocationThreshold: the anonymity revocation threshold
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
