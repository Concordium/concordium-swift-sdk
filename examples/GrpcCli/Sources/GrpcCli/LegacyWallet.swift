import ConcordiumSwiftSdk
import CryptoKit
import Foundation

enum LegacyWalletError: Error {
    case accountNotFound(address: AccountAddress)
}

class LegacyWallet: WalletProtocol {
    typealias Credential = CredentialIndex

    let accounts: [String: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]]

    init(accounts: [String: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]]) {
        self.accounts = accounts
    }

    func sign(_ message: Data, with account: ConcordiumSwiftSdk.Account<Credential>) throws -> [CredentialIndex: [KeyIndex: Data]] {
        guard let walletAccount = accounts[account.address.base58Check] else {
            throw LegacyWalletError.accountNotFound(address: account.address)
        }
        return try walletAccount.mapValues {
            try $0.mapValues {
                try $0.signature(for: message)
            }
        }
    }
}

struct LegacyWalletExport: Decodable {
    typealias CredentialIndex = String
    typealias KeyIndex = String

    var value: Value

    struct Value: Decodable {
        var identities: [Identity]
    }

    struct Identity: Decodable {
        var accounts: [Account]
    }

    struct Account: Decodable {
        var address: String
        var accountKeys: AccountKeys
    }

    struct AccountKeys: Decodable {
        var keys: [CredentialIndex: CredentialKeys]

        func toSdkType() throws -> [ConcordiumSwiftSdk.CredentialIndex: [ConcordiumSwiftSdk.KeyIndex: Curve25519.Signing.PrivateKey]] {
            try Dictionary(
                uniqueKeysWithValues: keys.map { credIdx, key in
                    try (
                        ConcordiumSwiftSdk.CredentialIndex(credIdx)!,
                        key.mapKeys()
                    )
                }
            )
        }
    }

    struct CredentialKeys: Decodable {
        var keys: [KeyIndex: Key]

        func toSdkType() throws -> [ConcordiumSwiftSdk.KeyIndex: Curve25519.Signing.PrivateKey] {
            try Dictionary(
                uniqueKeysWithValues: keys.map { keyIdx, key in
                    try (
                        ConcordiumSwiftSdk.KeyIndex(keyIdx)!,
                        Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: key.signKey))
                    )
                }
            )
        }
    }

    struct Key: Decodable {
        var signKey: String
        var verifyKey: String
    }

    func accountKeys() throws -> [String: [ConcordiumSwiftSdk.CredentialIndex: [ConcordiumSwiftSdk.KeyIndex: Curve25519.Signing.PrivateKey]]] {
        try Dictionary(
            uniqueKeysWithValues: value.identities.flatMap {
                try $0.accounts.map { account in
                    try (account.address, account.accountKeys.mapKeys())
                }
            }
        )
    }
}
