import ConcordiumWalletCrypto
import CryptoKit
import Foundation
import NIO

public func baseTransactionCost(headerByteCount: Int, payloadByteCount: Int, signatureCount: Int) -> Energy {
    let energyPerByte = 1
    let energyPerSignature = 100
    let sizeCost = Energy(energyPerByte * (headerByteCount + payloadByteCount))
    let signatureCost = Energy(energyPerSignature * signatureCount)
    return sizeCost + signatureCost
}

public struct AccountTransaction {
    public var sender: AccountAddress
    public var payload: AccountTransactionPayload

    public init(sender: AccountAddress, payload: AccountTransactionPayload) {
        self.sender = sender
        self.payload = payload
    }

    public func prepare(sequenceNumber: SequenceNumber, expiry: UInt64, signatureCount: Int) -> PreparedAccountTransaction {
        let serializedPayload = payload.serialize()
        // While the header size is fixed at the moment, it isn't guaranteed to stay true in the future.
        // As the cost depends on this size, we first create the header with no energy allocated.
        // We then serialize this header and patch the computed cost back on.
        // Updating the energy allocation will never affect the header size.
        var header = AccountTransactionHeader(sender: sender, sequenceNumber: sequenceNumber, maxEnergy: 0, expiry: expiry)
        header.maxEnergy = baseTransactionCost(
            headerByteCount: header.serialize(serializedPayloadSize: 0).count, // concrete payload size doesn't affect header size
            payloadByteCount: serializedPayload.count,
            signatureCount: signatureCount
        ) + payload.cost

        return PreparedAccountTransaction(header: header, serializedPayload: serializedPayload)
    }
}

public struct PreparedAccountTransaction {
    public var header: AccountTransactionHeader
    public var serializedPayload: Data

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += header.serializeInto(buffer: &buffer, serializedPayloadSize: UInt32(serializedPayload.count))
        res += buffer.writeData(serializedPayload)
        return res
    }

    public func serialize() -> SerializedAccountTransaction {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf)
        let data = Data(buffer: buf)
        return SerializedAccountTransaction(data: data)
    }
}

public struct SerializedAccountTransaction {
    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    public var hash: Data {
        Data(SHA256.hash(data: data))
    }
}

public typealias Signatures = [CredentialIndex: [KeyIndex: Data]]

public struct SignedAccountTransaction {
    public var transaction: PreparedAccountTransaction
    public var signatures: Signatures

    public init(transaction: PreparedAccountTransaction, signatures: Signatures) {
        self.transaction = transaction
        self.signatures = signatures
    }

    func toGrpcType() -> Concordium_V2_AccountTransaction {
        var p = Concordium_V2_AccountTransactionPayload()
        p.rawPayload = transaction.serializedPayload
        var s = Concordium_V2_AccountTransactionSignature()
        s.signatures = signatures.mapValues {
            var m = Concordium_V2_AccountSignatureMap()
            m.signatures = $0.reduce(into: [:]) { res, e in
                var s = Concordium_V2_Signature()
                s.value = e.value
                res[UInt32(e.key)] = s
            }
            return m
        }
        var t = Concordium_V2_AccountTransaction()
        t.header = transaction.header.toGrpcType()
        t.payload = p
//        t.payload = transaction.payload.toGrpcType()
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
            300
        }
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        switch self {
        case let .transfer(amount, receiver):
            var res = 0
            res += buffer.writeInteger(3, as: UInt8.self)
            res += buffer.writeData(receiver.data)
            res += buffer.writeInteger(amount, endianness: .big, as: UInt64.self)
            return res
        }
    }

    public func serialize() -> Data {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf)
        return Data(buffer: buf)
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
    public var sender: AccountAddress

    /// Sequence number of the transaction.
    public var sequenceNumber: SequenceNumber

    /// Maximum amount of energy the transaction can take to execute.
    public var maxEnergy: Energy

    /// Latest time the transaction can included in a block.
    public var expiry: TransactionTime

    public init(sender: AccountAddress, sequenceNumber: SequenceNumber, maxEnergy: Energy, expiry: TransactionTime) {
        self.sender = sender
        self.sequenceNumber = sequenceNumber
        self.maxEnergy = maxEnergy
        self.expiry = expiry
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer, serializedPayloadSize: UInt32) -> Int {
        var res = 0
        res += buffer.writeData(sender.data)
        res += buffer.writeInteger(sequenceNumber, endianness: .big, as: UInt64.self)
        res += buffer.writeInteger(maxEnergy, endianness: .big, as: UInt64.self)
        res += buffer.writeInteger(serializedPayloadSize, endianness: .big, as: UInt32.self)
        res += buffer.writeInteger(expiry, endianness: .big, as: UInt64.self)
        return res
    }

    public func serialize(serializedPayloadSize: UInt32) -> Data {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf, serializedPayloadSize: serializedPayloadSize)
        return Data(buffer: buf)
    }

    func toGrpcType() -> Concordium_V2_AccountTransactionHeader {
        var s = Concordium_V2_AccountAddress()
        s.value = sender.data
        var n = Concordium_V2_SequenceNumber()
        n.value = sequenceNumber
        var e = Concordium_V2_Energy()
        e.value = maxEnergy
        var x = Concordium_V2_TransactionTime()
        x.value = expiry
        var h = Concordium_V2_AccountTransactionHeader()
        h.sender = s
        h.sequenceNumber = n
        h.energyAmount = e
        h.expiry = x
        return h
    }
}

public struct AccountCredentialDeploymentPayload {
    public var deployment: AccountCredentialDeployment
}

public struct SignedAccountCredentialDeploymentTransaction {
    public var payload: AccountCredentialDeploymentPayload
    public var signatures: Signatures

    public init(payload: AccountCredentialDeploymentPayload, signatures: Signatures) {
        self.payload = payload
        self.signatures = signatures
    }

    public func serialize() throws -> SerializedSignedAccountCredentialDeploymentTransaction {
        SerializedSignedAccountCredentialDeploymentTransaction(payload: Data()) // TODO: ...
    }
}

public struct SerializedSignedAccountCredentialDeploymentTransaction {
    public var payload: Data

    public init(payload: Data) {
        self.payload = payload
    }

    func toGrpcType() -> Concordium_V2_CredentialDeployment {
        var d = Concordium_V2_CredentialDeployment()
        d.rawPayload = payload
        return d
    }
}
