import Foundation

public struct AccountTransaction {

    // From Android AccountActivity - client.sendTransaction:
    /*
    .sender(sender)
    .receiver(receiver)
    .amount(amount)
    .nonce(AccountNonce.from(nonce))
    .expiry(expiry)
    .signer(signer)
     */
    // Simple transfer: sendTransfer(senderAddress: String, receiverAddress: String, microCCDAmount: Long, privateKey: ED25519SecretKey)

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
    /// Returns true if `signature` has been explicitly set.
    var hasSignature: Bool {
        return self._signature != nil
    }

    /// Clears the value of `signature`. Subsequent reads from it will return its default value.
    mutating func clearSignature() {
        self._signature = nil
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
enum AccountTransactionPayload {
    case transfer(MicroCcdAmount)
    case transferWithMemo(TransferWithMemoPayload)

    func toGrpcType() -> Concordium_V2_AccountTransactionPayload {
        var result = Concordium_V2_AccountTransactionPayload()
        // TODO(RHA): Continue here
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
        grpcEnergy.value = energyAmount ?? 0 // TODO(RHA): What is the energy amount?

        var result = Concordium_V2_AccountTransactionHeader()
        result.sender = grpcSender
        result.sequenceNumber = grpcSequenceNumber
        result.energyAmount = grpcEnergy

        return result
    }
}

public struct TransferWithMemoPayload {

    /// Amount of CCD to send.
    var amount: MicroCcdAmount

    /// Receiver address.
    var receiver: AccountAddress

    /// Memo to include with the transfer.
    var memo: Memo
}

/*
enum TransactionTypeCost {
    case configureBaker
    case configureBakerWithProofs
    case configureDelegation
    case encryptedTransfer
    case transferToEncrypted
    case transferToPublic
    case encryptedTransferWithMemo
    case transferWithMemo
    case registerData
    case transferBaseCost

    var value: Energy {
        switch self {
        case .configureBaker: return 300
        case .configureBakerWithProofs: return 4050
        case .configureDelegation: return 500
        case .encryptedTransfer: return 27000
        case .transferToEncrypted: return 600
        case .transferToPublic: return 14850
        case .encryptedTransferWithMemo: return 27000
        case .transferWithMemo: return 300
        case .registerData: return 300
        case .transferBaseCost: return 300
        }
    }
}

 */

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