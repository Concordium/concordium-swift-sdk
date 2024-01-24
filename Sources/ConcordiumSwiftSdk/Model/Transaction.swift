import Foundation

struct AccountTransaction {

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
}

/// Energy is used to count exact execution cost.
/// This cost is then converted to CCD amounts.
typealias Energy = UInt64

/// Transaction time specified as seconds since unix epoch.
typealias TransactionTime = UInt64

/// Amount of CCD to send.
typealias Amount = UInt64

/// A memo which can be included as part of a transfer. Max size is 256 bytes.
typealias Memo = Data

/// The payload for an account transaction.
enum AccountTransactionPayload {
    case transfer(Amount)
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
}

struct TransferWithMemoPayload {

    /// Amount of CCD to send.
    var amount: Amount

    /// Receiver address.
    var receiver: AccountAddress

    /// Memo to include with the transfer.
    var memo: Memo
}