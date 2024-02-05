import CryptoKit
import Foundation

class TransactionHelper {
    let wallet: ConcordiumHdWallet
    let nodeClient: ConcordiumNodeClient

    public func sendSimpleTransfer(
        from sender: AccountAddress,
        to receiver: AccountAddress,
        amount: MicroCcdAmount,
        sequenceNumber: SequenceNumber,
        keys: [CredentialIndex: [KeyIndex: Curve25519.Signing.PrivateKey]]
    ) async throws -> TransactionHash {
        let inFiveMinsMs = UInt64(
            Date.now.addingTimeInterval(TimeInterval(5 * 60)).timeIntervalSince1970
        ) * 1000
        let payload = AccountTransactionPayload.transfer(amount, receiver)
        let messageToSign = "..." // TODO: !!

        let transaction = AccountTransaction(
            header: AccountTransactionHeader(
                sender: sender,
                sequenceNumber: sequenceNumber,
                energyAmount: TransactionTypeCost.transferBaseCost.value, // TODO: !!
                expiry: inFiveMinsMs
            ),
            payload: payload,
            signatures: keys.mapValues { $0.mapValues { try $0.signature(for: messageToSign) } }
        )
        return try await send(accountTransaction: transaction)
    }

    public func send(accountTransaction: AccountTransaction) async throws -> TransactionHash {
        var req = Concordium_V2_SendBlockItemRequest()
        req.accountTransaction = try accountTransaction.toGrpcType()
        let res = try await grpc.sendBlockItem(req).response.get()
        return res.value
    }
}
