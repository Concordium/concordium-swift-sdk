import ConcordiumWalletCrypto
import CryptoKit
import Foundation

public enum ConcordiumWalletError: Error {
    case mismatchingKeys
    case noCredentials
    case credentialCounterOutOfRange
}

public enum ConcordiumNetwork: String {
    case mainnet = "Mainnet"
    case testnet = "Testnet"
}

// TODO: Define 'SignerProtocol'?

public protocol ConcordiumWalletProtocol {
    func sign(_ message: Data, with account: ConcordiumAccount) throws -> [CredentialIndex: [KeyIndex: Data]]
}

public struct ConcordiumCredential {
    var identityProviderIndex: UInt32
    var identityIndex: UInt32
    var credentialCounter: UInt8
}

// TODO: Should be generic over credential type?
public struct ConcordiumAccount {
    var address: AccountAddress
    var credentials: [ConcordiumCredential]
}

public class ConcordiumHdWallet: ConcordiumWalletProtocol {
    let seed: ConcordiumWalletSeed

    public init(seed: ConcordiumWalletSeed) {
        self.seed = seed
    }

    public func generateAccount(credentials: [ConcordiumCredential], commitmentKey: String) throws -> ConcordiumAccount {
        guard let firstCred = credentials.first else {
            throw ConcordiumWalletError.noCredentials
        }
        let firstCredId = try seed.getCredentialId(of: firstCred, commitmentKey: commitmentKey)
        let addr = try SHA256.hash(data: Data(hex: firstCredId))
        return ConcordiumAccount(address: .init(Data(addr)), credentials: credentials)
    }

    public func sign(_ message: Data, with account: ConcordiumAccount) throws -> [CredentialIndex: [KeyIndex: Data]] {
        try Dictionary(uniqueKeysWithValues:
            account.credentials.enumerated().map { idx, cred in
                try (CredentialIndex(idx), sign(message, with: cred))
            }
        )
    }

    public func sign(_ message: Data, with credential: ConcordiumCredential) throws -> [KeyIndex: Data] {
        try [0: getCredentialKey(of: credential).signature(for: message)]
    }

    private func getCredentialKey(of credential: ConcordiumCredential) throws -> Curve25519.Signing.PrivateKey {
        let signingKey = try seed.getSigningKey(of: credential)
        let publicKey = try seed.getPublicKey(of: credential)
        let sk = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: signingKey))
        let pk = try Curve25519.Signing.PublicKey(rawRepresentation: Data(hex: publicKey))
        guard sk.publicKey.rawRepresentation == pk.rawRepresentation else {
            throw ConcordiumWalletError.mismatchingKeys
        }
        return sk
    }
}

/// Class for deriving cryptographic values related to credentials.
public class ConcordiumWalletSeed {
    let hex: String
    let network: ConcordiumNetwork

    public init(hex: String, network: ConcordiumNetwork) {
        self.hex = hex
        self.network = network
    }

    func getSigningKey(of credential: ConcordiumCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identityProviderIndex,
            identityIndex: credential.identityIndex,
            credentialCounter: UInt32(credential.credentialCounter)
        )
    }

    func getPublicKey(of credential: ConcordiumCredential) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identityProviderIndex,
            identityIndex: credential.identityIndex,
            credentialCounter: UInt32(credential.credentialCounter)
        )
    }

    func getCredentialId(of credential: ConcordiumCredential, commitmentKey: String) throws -> String {
        try ConcordiumWalletCrypto.getCredentialId(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identityProviderIndex,
            identityIndex: credential.identityIndex,
            credentialCounter: credential.credentialCounter,
            commitmentKey: commitmentKey
        )
    }

    func getPrfKey(identityProviderIndex: UInt32, identityIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getPrfKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex
        )
    }

    func getIdCredSec(identityProviderIndex: UInt32, identityIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getIdCredSec(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex
        )
    }

    func getSignatureBlindingRandomness(identityProviderIndex: UInt32, identityIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getSignatureBlindingRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: identityProviderIndex,
            identityIndex: identityIndex
        )
    }

    func getAttributeCommitmentRandomness(of credential: ConcordiumCredential, attribute: UInt8) throws -> String {
        try ConcordiumWalletCrypto.getAttributeCommitmentRandomness(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identityProviderIndex,
            identityIndex: credential.identityIndex,
            credentialCounter: UInt32(credential.credentialCounter),
            attribute: attribute
        )
    }

    func getVerifiableCredentialSigningKey(issuerIndex: UInt64, issuerSubindex: UInt64, verifiableCredentialIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialSigningKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: issuerIndex,
            issuerSubindex: issuerSubindex,
            verifiableCredentialIndex: verifiableCredentialIndex
        )
    }

    func getVerifiableCredentialPublicKey(issuerIndex: UInt64, issuerSubindex: UInt64, verifiableCredentialIndex: UInt32) throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialPublicKey(
            seedHex: hex,
            network: network.rawValue,
            issuerIndex: issuerIndex,
            issuerSubindex: issuerSubindex,
            verifiableCredentialIndex: verifiableCredentialIndex
        )
    }

    func getVerifiableCredentialBackupEncryptionKey() throws -> String {
        try ConcordiumWalletCrypto.getVerifiableCredentialBackupEncryptionKey(
            seedHex: hex,
            network: network.rawValue
        )
    }
}
