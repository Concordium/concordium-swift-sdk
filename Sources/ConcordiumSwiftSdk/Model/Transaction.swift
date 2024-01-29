import Foundation

public struct AccountTransaction {

    // TODO(RHA): Figure out what to do with/about the signature
    /*
    var signature: Concordium_V2_AccountTransactionSignature {
        get {
            return _signature ?? Concordium_V2_AccountTransactionSignature()
        }
        set {
            _signature = newValue
        }
    }
     */

    var header: AccountTransactionHeader

    var payload: AccountTransactionPayload

    func toGrpcType() -> Concordium_V2_AccountTransaction {
        var result = Concordium_V2_AccountTransaction()
        result.header = header.toGrpcType()
        result.payload = payload.toGrpcType()
        return result
    }
}

/// Energy is used to count exact execution cost.
/// This cost is then converted to CCD amounts.
public typealias Energy = UInt64

/// Transaction time specified as seconds since unix epoch.
public typealias TransactionTime = UInt64

/// A memo which can be included as part of a transfer. Max size is 256 bytes.
public typealias Memo = Data

/// The payload for an account transaction.
// TODO(RHA): How many different payloads should we support?
enum AccountTransactionPayload {
    case transfer(MicroCcdAmount)
    // case transferWithMemo(TransferWithMemoPayload) ...

    func toGrpcType() -> Concordium_V2_AccountTransactionPayload {
        var result = Concordium_V2_AccountTransactionPayload()

        switch self {
        case .transfer(let microCcdAmount):
            var transferPayload = Concordium_V2_TransferPayload()
            var amount = Concordium_V2_Amount()
            amount.value = microCcdAmount
            transferPayload.amount = amount
        }

        return result
    }
}

/// Header of an account transaction that contains basic data to check whether
/// the sender and the transaction are valid. The header is shared by all transaction types.
// TODO(RHA): Check required vs. optional fields - not just here, but on data in general
public struct AccountTransactionHeader {

    /// Sender of the transaction.
    var sender: AccountAddress

    /// Sequence number of the transaction.
    var sequenceNumber: SequenceNumber

    /// Maximum amount of energy the transaction can take to execute.
    var energyAmount: Energy?

    /// Latest time the transaction can included in a block.
    var expiry: TransactionTime?

    func toGrpcType() -> Concordium_V2_AccountTransactionHeader {
        var grpcSender = Concordium_V2_AccountAddress()
        grpcSender.value = sender.bytes

        var grpcSequenceNumber = Concordium_V2_SequenceNumber()
        grpcSequenceNumber.value = sequenceNumber

        var grpcEnergy = Concordium_V2_Energy()
        grpcEnergy.value = energyAmount ?? TransactionTypeCost.transferBaseCost.value

        var result = Concordium_V2_AccountTransactionHeader()
        result.sender = grpcSender
        result.sequenceNumber = grpcSequenceNumber
        result.energyAmount = grpcEnergy

        return result
    }
}

final class TransactionTypeCost {
    static let configureBaker = TransactionTypeCost(value: 300)
    static let configureBakerWithProofs = TransactionTypeCost(value: 4050)
    static let configureDelegation = TransactionTypeCost(value: 500)
    static let encryptedTransfer = TransactionTypeCost(value: 27000)
    static let transferToEncrypted = TransactionTypeCost(value: 600)
    static let transferToPublic = TransactionTypeCost(value: 14850)
    static let encryptedTransferWithMemo = TransactionTypeCost(value: 27000)
    static let transferWithMemo = TransactionTypeCost(value: 300)
    static let registerData = TransactionTypeCost(value: 300)
    static let transferBaseCost = TransactionTypeCost(value: 300)

    let value: UInt64

    private init(value: UInt64) {
        self.value = value
    }
}