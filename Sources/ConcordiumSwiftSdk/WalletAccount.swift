import CryptoKit
import Foundation

public class WalletAccount {
    public let address: AccountAddress
    public let keys: AccountKeysProtocol

    public init(address: AccountAddress, keys: AccountKeysProtocol) {
        self.address = address
        self.keys = keys
    }
}

public protocol WalletAccountRepositoryProtocol {
    func lookup(_ address: AccountAddress) throws -> WalletAccount?
    func insert(_ account: WalletAccount) throws
    func remove(_ address: AccountAddress) throws
}

public class WalletAccountStore: WalletAccountRepositoryProtocol {
    private var dictionary: [AccountAddress: WalletAccount] = [:]

    public init(_ accounts: [WalletAccount] = []) {
        accounts.forEach(insert)
    }

    public func lookup(_ address: AccountAddress) -> WalletAccount? {
        dictionary[address]
    }

    public func insert(_ account: WalletAccount) {
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
        try SignedAccountTransaction(
            transaction: transaction,
            signatures: sign(message: transaction.serialize().hash)
        )
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
