import CryptoKit
import Foundation
import NIO

// TODO: Include credentials?
public class Account {
    public let address: AccountAddress
    public let keys: Signer

    public init(address: AccountAddress, keys: Signer) {
        self.address = address
        self.keys = keys
    }
}

/// Conforming to this protocol allows producing signed variants of a number of
/// Concordium domain types which can be sent to a Concordium node
public protocol Signer {
    var count: Int { get }
    func sign(_ data: Data) throws -> Signatures
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
            signatures: sign(transaction.serialize().hash)
        )
    }

    func sign(deployment: AccountCredential, expiry: TransactionTime) throws -> SignedAccountCredentialDeployment {
        try sign(deployment: deployment.prepareDeployment(expiry: expiry))
    }

    func sign(deployment: PreparedAccountCredentialDeployment) throws -> SignedAccountCredentialDeployment {
        let signatures = try sign(deployment.hash)
        let signaturesCred0 = signatures[0]! // account has exactly one credential (the one we're signing)
        return .init(deployment: deployment, signatures: signaturesCred0)
    }

    func sign(message: Data, address: AccountAddress) throws -> Signatures {
        var buf = ByteBuffer()
        buf.writeData(address.data)
        buf.writeRepeatingByte(0, count: 8)
        buf.writeData(message)
        let data = Data(buffer: buf)
        let hash = Data(SHA256.hash(data: data))
        return try sign(hash)
    }
}

/// Conforming to this protocol requires being able to produce signatures for an arbitrary byte sequence.
public protocol AccountKey {
    /// Produce a signature for the given ``Data``
    func signature(for data: Data) throws -> Data
}

/// Represents a Ed25519 private key
public typealias AccountKeyCurve25519 = Curve25519.Signing.PrivateKey

extension AccountKeyCurve25519: AccountKey {
    // Automatically conforming via `Curve25519.Signing.PrivateKey`.
}

/// Represents a set consisting of one or more ``AccountKeyCurve25519``s
public typealias AccountKeysCurve25519 = AccountKeys<AccountKeyCurve25519>

/// Represents a set of ``AccountKey``s structured in a map of ``[CredentialIndex: [KeyIndex: any AccountKey]]``.
/// Calling `sign` produces an equally structured ``Signatures`` map
public struct AccountKeys<Key: AccountKey>: Signer {
    public let keys: [CredentialIndex: [KeyIndex: Key]]

    public init(_ keys: [CredentialIndex: [KeyIndex: Key]]) {
        self.keys = keys
    }

    /// Initializes from a single key, asigning it to the first credential and key index.
    public init(key: Key) {
        self.init([0: [0: key]])
    }

    /// The number of keys in total
    public var count: Int {
        keys.reduce(0) { acc, cred in acc + cred.value.count }
    }

    /// Signs the data, producing a map of signatures corresponding to the map of keys.
    ///
    /// - Parameter data: The data to sign
    /// - Throws: if a valid signature could not be produced
    /// - Returns: ``Signatures`` if successful
    public func sign(_ data: Data) throws -> Signatures {
        try keys.mapValues {
            try $0.mapValues {
                try $0.signature(for: data)
            }
        }
    }
}

extension AccountKeys: Decodable where Key == AccountKeyCurve25519 {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try container.decode(AccountKeysJSON.self).toSDKType()
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
