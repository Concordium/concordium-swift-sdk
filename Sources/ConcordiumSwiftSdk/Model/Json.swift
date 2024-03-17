import CryptoKit
import Foundation

public struct AccountKeysJson: Decodable {
    public var keys: [String: CredentialKeys]

    public func toSdkType() throws -> AccountKeysCurve25519 {
        try AccountKeysCurve25519(
            Dictionary(
                uniqueKeysWithValues: keys.map { credIdx, key in
                    try (
                        CredentialIndex(credIdx)!,
                        key.toSdkType()
                    )
                }
            )
        )
    }

    public struct CredentialKeys: Decodable {
        public var keys: [String: Key]

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

    public struct Key: Decodable {
        public var signKey: String
        public var verifyKey: String

        public func toSdkType() throws -> Curve25519.Signing.PrivateKey {
            try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: signKey))
        }
    }
}

public struct LegacyWalletExportJson: Decodable {
    public var value: Value

    public func toSdkType() throws -> [ConcordiumSwiftSdk.Account] {
        try value.identities.flatMap {
            try $0.accounts.map { account in
                try ConcordiumSwiftSdk.Account(
                    address: AccountAddress(base58Check: account.address),
                    keys: account.accountKeys.toSdkType()
                )
            }
        }
    }

    public struct Value: Decodable {
        public var identities: [Identity]
    }

    public struct Identity: Decodable {
        public var accounts: [Account]
    }

    public struct Account: Decodable {
        public var address: String
        public var accountKeys: AccountKeysJson
    }
}
