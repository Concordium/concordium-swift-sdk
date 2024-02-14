import CryptoKit
import Foundation

class Transactions {
    let wallet: ConcordiumWalletProtocol
    let nodeClient: ConcordiumNodeClient

    init(_ wallet: ConcordiumWalletProtocol, _ nodeClient: ConcordiumNodeClient) {
        self.wallet = wallet
        self.nodeClient = nodeClient
    }

//    public func simpleTransfer(
//        from sender: ConcordiumAccount,
//        to receiver: AccountAddress,
//        amount: MicroCcdAmount,
//        sequenceNumber: SequenceNumber,
//        validMinutes: Int,
//
//    ) async throws -> TransactionHash {
//        let n = try await nodeClient.getNextAccountSequenceNumber(of: sender.address)
//        let tx = AccountTransaction.simpleTransfer(
//                from: sender,
//                to: receiver,
//                amount: amount,
//                sequenceNumber: n.sequenceNumber,
//                expiry: UInt64(
//                        Date().addingTimeInterval(TimeInterval(validMinutes * 60)).timeIntervalSince1970
//                )
//        )
//        return try await signAndSend(transaction: tx, with: sender)
//    }

//    private func signAndSend(transaction: AccountTransaction, with account: ConcordiumAccount) async throws -> TransactionHash {
//        try await send(sign(transaction, with: account))
//    }

    private func sign(_ transaction: AccountTransaction, with account: ConcordiumAccount) throws -> SignedAccountTransaction {
        let serialized = try transaction.serialize()
        let signatures = try wallet.sign(serialized.hash, with: account)
        return SignedAccountTransaction(
            transaction: transaction,
            signatures: signatures
        )
    }

    public func send(_ transaction: SignedAccountTransaction) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        req.accountTransaction = try transaction.toGrpcType()
        // TODO: !!
//        let res = try await nodeClient.sendBlockItem(req).response.get()
//        return res.value
        return Data()
    }
}
