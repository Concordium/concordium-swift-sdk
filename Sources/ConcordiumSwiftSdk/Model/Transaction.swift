import CryptoKit
import Foundation

public struct AccountTransaction {
    var header: AccountTransactionHeader
    var payload: AccountTransactionPayload
    var signatures: [CredentialIndex: [KeyIndex: Data]]

    func toGrpcType() throws -> Concordium_V2_AccountTransaction {
        var s = Concordium_V2_AccountTransactionSignature()
        s.signatures = signatures.mapValues {
            var m = Concordium_V2_AccountSignatureMap()
            m.signatures = $0.mapValues {
                var s = Concordium_V2_Signature()
                s.value = $0
                return s
            }
            return m
        }
        var t = Concordium_V2_AccountTransaction()
        t.header = header.toGrpcType()
        t.payload = payload.toGrpcType()
        t.signature = s
        return t
    }
}

/// Energy is used to count exact execution cost.
/// This cost is then converted to CCD amounts.
public typealias Energy = UInt64

/// Transaction time specified as seconds since unix epoch.
public typealias TransactionTime = UInt64

/// A memo which can be included as part of a transfer. Max size is 256 bytes.
public typealias Memo = Data

/// The payload for an account transaction (only transfer is supported for now).
public enum AccountTransactionPayload {
    case transfer(amount: MicroCcdAmount, receiver: AccountAddress)

    func toGrpcType() -> Concordium_V2_AccountTransactionPayload {
        switch self {
        case let .transfer(amount, receiver):
            var a = Concordium_V2_Amount()
            a.value = amount
            var r = Concordium_V2_AccountAddress()
            r.value = receiver.bytes
            var p = Concordium_V2_TransferPayload()
            p.amount = a
            p.receiver = r
            var t = Concordium_V2_AccountTransactionPayload()
            t.transfer = p
            return t
        }
    }
}

/// Header of an account transaction that contains basic data to check whether
/// the sender and the transaction are valid. The header is shared by all transaction types.
public struct AccountTransactionHeader {
    /// Sender of the transaction.
    var sender: AccountAddress

    /// Sequence number of the transaction.
    var sequenceNumber: SequenceNumber

    /// Maximum amount of energy the transaction can take to execute.
    var maxEnergy: Energy

    /// Latest time the transaction can included in a block.
    var expiry: TransactionTime?

    func toGrpcType() -> Concordium_V2_AccountTransactionHeader {
        var s = Concordium_V2_AccountAddress()
        s.value = sender.bytes
        var n = Concordium_V2_SequenceNumber()
        n.value = sequenceNumber
        var e = Concordium_V2_Energy()
        e.value = maxEnergy
        var h = Concordium_V2_AccountTransactionHeader()
        h.sender = s
        h.sequenceNumber = n
        h.energyAmount = e
        return h
    }
}

public struct TransactionTypeCost {
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

    var value: UInt64
}

// TODO[mo]: Looks like something that should be a simple function.
public struct EnergyCost {
    static let constantA: UInt64 = 100
    static let constantB: UInt64 = 1

    /// Account address (32 bytes), nonce (8 bytes), energy (8 bytes), payload size (4 bytes), expiry (8 bytes);
    static let accountTransactionHeaderSize: UInt64 = 32 + 8 + 8 + 4 + 8

    /// Calculates the energy cost for a transaction.
    ///
    /// The energy cost is determined by the formula: A * signatureCount + B * size + C_t,
    /// where A and B are constants, and C_t is a transaction-specific cost.
    ///
    /// - Parameters:
    ///   - signatureCount: Number of signatures for the transaction.
    ///   - payloadSize: Size of the payload in bytes.
    ///   - transactionSpecificCost: A transaction-specific cost.
    ///
    /// - Returns: The energy cost for the transaction.
    public func calculate(
        signatureCount: UInt64,
        payloadSize: UInt64,
        transactionSpecificCost: UInt64
    ) -> UInt64 {
        constantA * signatureCount +
            constantB * (accountTransactionHeaderSize + payloadSize) +
            transactionSpecificCost
    }
}
