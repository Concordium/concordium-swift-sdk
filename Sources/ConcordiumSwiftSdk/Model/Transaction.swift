import CryptoKit
import Foundation
import NIO

public struct AccountTransaction {
    var header: AccountTransactionHeader
    var payload: AccountTransactionPayload

    @discardableResult func serializeInto(buffer: inout ByteBuffer) -> Int {
        var payloadBuf = ByteBuffer()
        let size = payload.serializeInto(buffer: &payloadBuf)
        var res = 0
        res += header.serializeInto(buffer: &buffer, serializedPayloadCount: UInt32(size))
        res += buffer.writeBuffer(&payloadBuf)
        return res
    }

    func serialize() throws -> SerializedAccountTransaction {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf)
        let data = Data(buffer: buf)
        return SerializedAccountTransaction(data: data)
    }

    public static func simpleTransfer(
        from sender: ConcordiumAccount,
        to receiver: AccountAddress,
        amount: MicroCcdAmount,
        sequenceNumber: SequenceNumber,
        expiry: UInt64
    ) -> AccountTransaction {
        AccountTransaction(
            header: AccountTransactionHeader(
                sender: sender.address,
                sequenceNumber: sequenceNumber,
                maxEnergy: 501, // TODO: !!
                expiry: expiry
            ),
            payload: AccountTransactionPayload.transfer(amount: amount, receiver: receiver)
        )
    }
}

public struct SerializedAccountTransaction {
    let data: Data
    var hash: Data {
        Data(SHA256.hash(data: data))
    }
}

public struct SignedAccountTransaction {
    var transaction: AccountTransaction
    var signatures: [CredentialIndex: [KeyIndex: Data]]

    var cost: Energy {
        // TODO: Add cost for signatures.
        transaction.header.maxEnergy
    }

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
        t.header = transaction.header.toGrpcType()
        t.payload = transaction.payload.toGrpcType()
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

    var cost: Energy {
        switch self {
        case .transfer:
            return 300
        }
    }

    @discardableResult func serializeInto(buffer: inout ByteBuffer) -> Int {
        switch self {
        case let .transfer(amount, receiver):
            var res = 0
            res += buffer.writeInteger(3, as: UInt8.self)
            res += buffer.writeData(receiver.data)
            res += buffer.writeInteger(amount, endianness: .big, as: UInt64.self)
            return res
        }
    }

    func toGrpcType() -> Concordium_V2_AccountTransactionPayload {
        switch self {
        case let .transfer(amount, receiver):
            var a = Concordium_V2_Amount()
            a.value = amount
            var r = Concordium_V2_AccountAddress()
            r.value = receiver.data
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
    var expiry: TransactionTime

    var cost: Energy {
        // TODO: !!
        0
    }

    @discardableResult func serializeInto(buffer: inout ByteBuffer, serializedPayloadCount: UInt32) -> Int {
        var res = 0
        res += buffer.writeData(sender.data)
        res += buffer.writeInteger(sequenceNumber, endianness: .big, as: UInt64.self)
        res += buffer.writeInteger(maxEnergy, endianness: .big, as: UInt64.self)
        res += buffer.writeInteger(serializedPayloadCount, endianness: .big, as: UInt32.self)
        res += buffer.writeInteger(expiry, endianness: .big, as: UInt64.self)
        return res
    }

    func toGrpcType() -> Concordium_V2_AccountTransactionHeader {
        var s = Concordium_V2_AccountAddress()
        s.value = sender.data
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
