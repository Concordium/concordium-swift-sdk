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

// TODO: Define 'SignerProtocol'?

public protocol WalletProtocol {
    func sign(_ message: Data, with account: Account) throws -> [CredentialIndex: [KeyIndex: Data]]
}

public struct Credential {
    var identityProviderIndex: UInt32
    var identityIndex: UInt32
    var credentialCounter: UInt8
}

// TODO: Should be generic over credential type?
public struct Account {
    var address: AccountAddress
    var credentials: [Credential]
}

public class SeedBasedWallet: WalletProtocol {
    let seed: WalletSeed

    public init(seed: WalletSeed) {
        self.seed = seed
    }

    public func generateAccount(credentials: [Credential], commitmentKey: String) throws -> Account {
        guard let firstCred = credentials.first else {
            throw WalletError.noCredentials
        }
        let firstCredId = try seed.getCredentialId(of: firstCred, commitmentKey: commitmentKey)
        let addr = try SHA256.hash(data: Data(hex: firstCredId))
        return Account(address: .init(Data(addr)), credentials: credentials)
    }

    public func sign(_ message: Data, with account: Account) throws -> [CredentialIndex: [KeyIndex: Data]] {
        try Dictionary(uniqueKeysWithValues:
            account.credentials.enumerated().map { idx, cred in
                try (CredentialIndex(idx), sign(message, with: cred))
            }
        )
    }

    public func sign(_ message: Data, with credential: Credential) throws -> [KeyIndex: Data] {
        try [0: getCredentialKey(of: credential).signature(for: message)]
    }

    private func getCredentialKey(of credential: Credential) throws -> Curve25519.Signing.PrivateKey {
        let signingKey = try seed.getSigningKey(of: credential)
        let publicKey = try seed.getPublicKey(of: credential)
        let sk = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: signingKey))
        let pk = try Curve25519.Signing.PublicKey(rawRepresentation: Data(hex: publicKey))
        guard sk.publicKey.rawRepresentation == pk.rawRepresentation else {
            throw WalletError.mismatchingKeys
        }
        return sk
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

    func getSigningKey(of credential: Credential) throws -> String {
        try ConcordiumWalletCrypto.getAccountSigningKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identityProviderIndex,
            identityIndex: credential.identityIndex,
            credentialCounter: UInt32(credential.credentialCounter)
        )
    }

    func getPublicKey(of credential: Credential) throws -> String {
        try ConcordiumWalletCrypto.getAccountPublicKey(
            seedHex: hex,
            network: network.rawValue,
            identityProviderIndex: credential.identityProviderIndex,
            identityIndex: credential.identityIndex,
            credentialCounter: UInt32(credential.credentialCounter)
        )
    }

    func getCredentialId(of credential: Credential, commitmentKey: String) throws -> String {
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

    func getAttributeCommitmentRandomness(of credential: Credential, attribute: UInt8) throws -> String {
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
