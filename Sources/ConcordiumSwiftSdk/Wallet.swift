import CryptoKit
import Foundation

public enum WalletError: Error {
    case accountNotFound
}

public class Wallet {
    public let accountStore: AccountStoreProtocol

    public init(accountStore: AccountStoreProtocol) {
        self.accountStore = accountStore
    }

    public func prepareAndSign(transaction: AccountTransaction, sequenceNumber: SequenceNumber, expiry: TransactionTime) throws -> SignedAccountTransaction {
        guard let account = try accountStore.lookup(address: transaction.sender) else {
            throw WalletError.accountNotFound
        }
        let preparedTransaction = transaction.prepare(
            sequenceNumber: sequenceNumber,
            expiry: expiry,
            signatureCount: account.keys.count
        )
        return try account.keys.sign(transaction: preparedTransaction)
    }

    public func sign(transaction: PreparedAccountTransaction) throws -> SignedAccountTransaction {
        guard let account = try accountStore.lookup(address: transaction.header.sender) else {
            throw WalletError.accountNotFound
        }
        return try account.keys.sign(transaction: transaction)
    }
}

public protocol AccountStoreProtocol {
    func lookup(address: AccountAddress) throws -> WalletAccount?
}

public class SimpleAccountStore: AccountStoreProtocol {
    private var dictionary: [AccountAddress: WalletAccount] = [:]

    public init(_ accounts: [WalletAccount] = []) {
        accounts.forEach(insert)
    }

    public func insert(_ account: WalletAccount) {
        dictionary[account.address] = account
    }

    public func remove(address: AccountAddress) {
        dictionary[address] = nil
    }

    public func lookup(address: AccountAddress) -> WalletAccount? {
        dictionary[address]
    }
}

public class WalletAccount {
    public let address: AccountAddress
    public let keys: AccountKeys

    public init(address: AccountAddress, keys: AccountKeys) {
        self.address = address
        self.keys = keys
    }
}

public class AccountKeys {
    let keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]

    public init(_ keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]) {
        self.keys = keys
    }

    public var count: Int {
        keys.reduce(0) { acc, cred in acc + cred.value.count }
    }

    public func sign(_ message: Data) throws -> [CredentialIndex: [KeyIndex: Data]] {
        try keys.mapValues {
            try $0.mapValues {
                try $0.signature(for: message)
            }
        }
    }

    public func sign(transaction: PreparedAccountTransaction) throws -> SignedAccountTransaction {
        let hash = transaction.serialize().hash
        let signatures = try sign(hash)
        return SignedAccountTransaction(transaction: transaction, signatures: signatures)
    }
}
