import CryptoKit
import Foundation

// TODO: Include credentials?
public class Account {
    public let address: AccountAddress
    public let keys: Signer

    public init(address: AccountAddress, keys: Signer) {
        self.address = address
        self.keys = keys
    }
}

public protocol Signer {
    var count: Int { get }
    func sign(message: Data) throws -> Signatures
}

public extension Signer {
    func sign(transaction: AccountTransaction, sequenceNumber: SequenceNumber, expiry: TransactionTime) throws -> SignedAccountTransaction {
        try sign(
            transaction: transaction.prepare(
                sequenceNumber: sequenceNumber,
                expiry: expiry,
                signatureCount: count
            )
        )
    }

    func sign(transaction: PreparedAccountTransaction) throws -> SignedAccountTransaction {
        try .init(
            transaction: transaction,
            signatures: sign(message: transaction.serialize().hash)
        )
    }

    func sign(deployment: AccountCredential, expiry: TransactionTime) throws -> SignedAccountCredentialDeployment {
        try sign(deployment: deployment.prepareDeployment(expiry: expiry))
    }

    func sign(deployment: PreparedAccountCredentialDeployment) throws -> SignedAccountCredentialDeployment {
        let signatures = try sign(message: deployment.hash)
        let signaturesCred0 = signatures[0]! // account has exactly one credential (the one we're signing)
        return .init(deployment: deployment, signatures: signaturesCred0)
    }
}

public protocol AccountKey {
    func signature(for data: Data) throws -> Data
}

public typealias AccountKeyCurve25519 = Curve25519.Signing.PrivateKey

extension AccountKeyCurve25519: AccountKey {
    // Automatically conforming via `Curve25519.Signing.PrivateKey`.
}

public typealias AccountKeysCurve25519 = AccountKeys<AccountKeyCurve25519>

public class AccountKeys<Key: AccountKey>: Signer {
    public let keys: [CredentialIndex: [KeyIndex: Key]]

    public init(_ keys: [CredentialIndex: [KeyIndex: Key]]) {
        self.keys = keys
    }

    public var count: Int {
        keys.reduce(0) { acc, cred in acc + cred.value.count }
    }

    public func sign(message: Data) throws -> Signatures {
        try keys.mapValues {
            try $0.mapValues {
                try $0.signature(for: message)
            }
        }
    }
}

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

        public func toSDKType() throws -> [KeyIndex: AccountKeyCurve25519] {
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

        public func toSDKType() throws -> AccountKeyCurve25519 {
            try AccountKeyCurve25519(rawRepresentation: Data(hex: signKey))
        }
    }
}
