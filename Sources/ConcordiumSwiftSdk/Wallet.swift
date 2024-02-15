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
    func sign(_ message: Data, with account: Account) throws -> [CredentialIndex: [KeyIndex: Data]]
}

public struct Identity {
    var providerIndex: UInt32
    var index: UInt32
}

public struct IdentityCredential {
    var identity: Identity
    var counter: UInt8
}

public struct Issuer {
    var index: UInt64
    var subindex: UInt64
}

public struct VerifiableCredential {
    var issuer: Issuer
    var index: UInt32
}

public struct Account {
    var address: AccountAddress
    var credentials: [IdentityCredential]
}

public class SeedBasedWallet: WalletProtocol {
    let seed: WalletSeed

    public init(seed: WalletSeed) {
        self.seed = seed
    }

    public func generateAccount(credentials: [IdentityCredential], commitmentKey: String) throws -> Account {
        guard let firstCred = credentials.first else {
            throw WalletError.noCredentials
        }
        let firstCredId = try seed.id(of: firstCred, commitmentKey: commitmentKey)
        let addr = try SHA256.hash(data: Data(hex: firstCredId))
        return Account(address: .init(Data(addr)), credentials: credentials)
    }

    public func sign(_ message: Data, with account: Account) throws -> [CredentialIndex: [KeyIndex: Data]] {
        try Dictionary(
            uniqueKeysWithValues: account.credentials.enumerated().map { idx, cred in
                try (CredentialIndex(idx), sign(message, with: cred))
            }
        )
    }

    public func sign(_ message: Data, with credential: IdentityCredential) throws -> [KeyIndex: Data] {
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

    func signingKey(of credential: IdentityCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    func publicKey(of credential: IdentityCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter)
        )
    }

    func id(of credential: IdentityCredential, commitmentKey: String) throws -> String {
        try ConcordiumWalletCrypto.getCredentialId(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: credential.counter,
            commitmentKey: commitmentKey
        )
    }

    func prfKey(of identity: Identity) throws -> String {
        try ConcordiumWalletCrypto.getPrfKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    func credSec(of identity: Identity) throws -> String {
        try ConcordiumWalletCrypto.getIdCredSec(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    func signatureBlindingRandomness(of identity: Identity) throws -> String {
        try ConcordiumWalletCrypto.getSignatureBlindingRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identity.providerIndex,
            identityIndex: identity.index
        )
    }

    func attributeCommitmentRandomness(of credential: IdentityCredential, attribute: UInt8) throws -> String {
        try ConcordiumWalletCrypto.getAttributeCommitmentRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identity.providerIndex,
            identityIndex: credential.identity.index,
            credentialCounter: UInt32(credential.counter),
            attribute: attribute
        )
    }

    func signingKey(of verifiableCredential: VerifiableCredential) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialSigningKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    func publicKey(of verifiableCredential: VerifiableCredential) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialPublicKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: verifiableCredential.issuer.index,
            issuerSubindex: verifiableCredential.issuer.subindex,
            verifiableCredentialIndex: verifiableCredential.index
        )
    }

    func verifiableCredentialBackupEncryptionKey() throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialBackupEncryptionKey(
            seedHex: hex,
            network: network.rawValue
        )
    }
}
