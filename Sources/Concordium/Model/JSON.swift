import CryptoKit
import Foundation

public struct AccountKeysJSON: Decodable {
    public var keys: [String: CredentialKeys]

    public func toSDKType() throws -> AccountKeysCurve25519 {
        try AccountKeysCurve25519(
            Dictionary(
                uniqueKeysWithValues: keys.map { credIdx, key in
                    try (
                        CredentialIndex(credIdx)!,
                        key.toSDKType()
                    )
                }
            )
        )
    }

    public struct CredentialKeys: Decodable {
        public var keys: [String: Key]

        public func toSDKType() throws -> [KeyIndex: Curve25519.Signing.PrivateKey] {
            try Dictionary(
                uniqueKeysWithValues: keys.map { keyIdx, key in
                    try (
                        KeyIndex(keyIdx)!,
                        key.toSDKType()
                    )
                }
            )
        }
    }

    public struct Key: Decodable {
        public var signKey: String
        public var verifyKey: String

        public func toSDKType() throws -> Curve25519.Signing.PrivateKey {
            try Curve25519.Signing.PrivateKey(rawRepresentation: Data(hex: signKey))
        }
    }
}

public struct LegacyWalletExportJSON: Decodable {
    public var v: Int // TODO: let decoding fail if `v` differs from '1'.
    public var type: String // TODO: let decoding fail if `type` differs from "concordium-mobile-wallet-data"
    public var environment: String
    public var value: Value

    public func toSDKType() throws -> [Concordium.Account] {
        try value.identities.flatMap {
            try $0.accounts.map { account in
                try Concordium.Account(
                    address: AccountAddress(base58Check: account.address),
                    keys: account.accountKeys.toSDKType()
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
        public var accountKeys: AccountKeysJSON
    }
}
