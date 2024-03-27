import CryptoKit
import Foundation

// TODO: Include credentials?
public class Account {
    public let address: AccountAddress
    public let keys: AccountKeysProtocol

    public init(address: AccountAddress, keys: AccountKeysProtocol) {
        self.address = address
        self.keys = keys
    }
}

public protocol AccountRepositoryProtocol {
    func lookup(_ address: AccountAddress) throws -> Account?
    func insert(_ account: Account) throws
    func remove(_ address: AccountAddress) throws
}

public class AccountStore: AccountRepositoryProtocol {
    private var dictionary: [AccountAddress: Account] = [:]

    public init(_ accounts: [Account] = []) {
        accounts.forEach(insert)
    }

    public func lookup(_ address: AccountAddress) -> Account? {
        dictionary[address]
    }

    public func insert(_ account: Account) {
        dictionary[account.address] = account
    }

    public func remove(_ address: AccountAddress) {
        dictionary[address] = nil
    }
}

public protocol AccountKeysProtocol {
    var count: Int { get }
    func sign(message: Data) throws -> Signatures
}

public extension AccountKeysProtocol {
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

public protocol AccountKeyProtocol {
    func signature(for data: Data) throws -> Data
}

extension Curve25519.Signing.PrivateKey: AccountKeyProtocol {}

public typealias AccountKeysCurve25519 = AccountKeys<Curve25519.Signing.PrivateKey>

public class AccountKeys<Key: AccountKeyProtocol>: AccountKeysProtocol {
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
