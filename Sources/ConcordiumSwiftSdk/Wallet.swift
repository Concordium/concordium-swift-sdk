import CryptoKit
import Foundation

public enum WalletError: Error {
    case accountNotFound
}

public protocol WalletProtocol {
    func lookup(address: AccountAddress) -> WalletAccount?
}

public extension WalletProtocol {
    func sign(transaction: PreparedAccountTransaction) throws -> SignedAccountTransaction {
        guard let account = lookup(address: transaction.header.sender) else {
            throw WalletError.accountNotFound
        }
        // Note that this isn't the final hash returned by 'client.send' because that one includes the signatures.
        let hash = transaction.serialize().hash
        let signatures = try account.keys.sign(hash)
        return SignedAccountTransaction(transaction: transaction, signatures: signatures)
    }
}

public class SimpleWallet: WalletProtocol {
    private var accounts: [AccountAddress: WalletAccount]

    public init(accounts: [AccountAddress: WalletAccount] = [:]) {
        self.accounts = accounts
    }

    public func insert(account: WalletAccount) {
        accounts[account.address] = account
    }

    public func remove(address: AccountAddress) {
        accounts[address] = nil
    }

    public func lookup(address: AccountAddress) -> WalletAccount? {
        accounts[address]
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
}
