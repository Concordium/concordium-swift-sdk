import Foundation

struct AccountTransaction {

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
        result.header
    }
}

/// Energy is used to count exact execution cost.
/// This cost is then converted to CCD amounts.
typealias Energy = UInt64

/// Transaction time specified as seconds since unix epoch.
typealias TransactionTime = UInt64

/// A memo which can be included as part of a transfer. Max size is 256 bytes.
typealias Memo = Data

/// The payload for an account transaction.
enum AccountTransactionPayload {
    case transfer(MicroCcdAmount)
    case transferWithMemo(TransferWithMemoPayload)
}

/// Header of an account transaction that contains basic data to check whether
/// the sender and the transaction are valid. The header is shared by all transaction types.
// TODO(RHA): Check required vs. optional fields - not just here, but on data in general
struct AccountTransactionHeader {

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
        grpcEnergy.value = energyAmount

        var result = Concordium_V2_AccountTransactionHeader()
        result.sender = grpcSender
        result.sequenceNumber = grpcSequenceNumber
        result.energyAmount = grpcEnergy

        return result
    }
}

struct TransferWithMemoPayload {

    /// Amount of CCD to send.
    var amount: Amount

    /// Receiver address.
    var receiver: AccountAddress

    /// Memo to include with the transfer.
    var memo: Memo
}