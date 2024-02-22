import CryptoKit
import Foundation

public struct LegacyWalletExportJson: Decodable {
    public var value: ValueJson

    public func toWallet() throws -> SimpleWallet {
        try SimpleWallet(
            accounts: Dictionary(
                uniqueKeysWithValues: value.identities.flatMap {
                    try $0.accounts.map { account in
                        let a = try AccountAddress(base58Check: account.address)
                        return try (a, WalletAccount(address: a, keys: AccountKeys(account.accountKeys.toSdkType())))
                    }
                }
            )
        )
    }

    public struct ValueJson: Decodable {
        public var identities: [IdentityJson]
    }

    public struct IdentityJson: Decodable {
        public var accounts: [AccountJson]
    }

    public struct AccountJson: Decodable {
        public var address: String
        public var accountKeys: AccountKeysJson
    }

    public struct AccountKeysJson: Decodable {
        public var keys: [String: CredentialKeysJson]

        public func toSdkType() throws -> [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]] {
            try Dictionary(
                uniqueKeysWithValues: keys.map { credIdx, key in
                    try (
                        CredentialIndex(credIdx)!,
                        key.toSdkType()
                    )
                }
            )
        }
    }

    public struct CredentialKeysJson: Decodable {
        public var keys: [String: KeyJson]

        public func toSdkType() throws -> [KeyIndex: Curve25519.Signing.PrivateKey] {
            try Dictionary(
                uniqueKeysWithValues: keys.map { keyIdx, key in
                    try (
                        KeyIndex(keyIdx)!,
                        key.toSdkType()
                    )
                }
            )
        }
    }

    public struct KeyJson: Decodable {
        public var signKey: String
        public var verifyKey: String

        public func toSdkType() throws -> Curve25519.Signing.PrivateKey {
            try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: signKey))
        }
    }
}
