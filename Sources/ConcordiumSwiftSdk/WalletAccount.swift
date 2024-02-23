import CryptoKit
import Foundation

public class WalletAccount {
    public let address: AccountAddress
    public let keys: AccountKeys

    public init(address: AccountAddress, keys: AccountKeys) {
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

public protocol TransactionSignerProtocol {
    func sign(_ message: Data) throws -> Signatures
    func sign(_ transaction: AccountTransaction, sequenceNumber: SequenceNumber, expiry: TransactionTime) throws -> SignedAccountTransaction
}

public class AccountKeys: TransactionSignerProtocol {
    public let keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]

    public init(_ keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]) {
        self.keys = keys
    }

    public var count: Int {
        keys.reduce(0) { acc, cred in acc + cred.value.count }
    }

    public func sign(_ message: Data) throws -> Signatures {
        try keys.mapValues {
            try $0.mapValues {
                try $0.signature(for: message)
            }
        }
    }

    public func sign(_ transaction: AccountTransaction, sequenceNumber: SequenceNumber, expiry: TransactionTime) throws -> SignedAccountTransaction {
        try sign(
            transaction.prepare(
                sequenceNumber: sequenceNumber,
                expiry: expiry,
                signatureCount: count
            )
        )
    }

    public func sign(_ transaction: PreparedAccountTransaction) throws -> SignedAccountTransaction {
        try SignedAccountTransaction(
            transaction: transaction,
            signatures: sign(transaction.serialize().hash)
        )
    }
}
