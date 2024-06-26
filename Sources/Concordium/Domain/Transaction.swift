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
        return .init(header: header, serializedPayload: serializedPayload)
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
        return .init(data: data)
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

public typealias Signatures = [CredentialIndex: CredentialSignatures]
public typealias CredentialSignatures = [KeyIndex: Data]

public struct SignedAccountTransaction: ToGRPC {
    public var transaction: PreparedAccountTransaction
    public var signatures: Signatures

    public init(transaction: PreparedAccountTransaction, signatures: Signatures) {
        self.transaction = transaction
        self.signatures = signatures
    }

    func toGRPC() -> Concordium_V2_AccountTransaction {
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
        t.header = transaction.header.toGRPC()
        t.payload = p
        t.signature = s
        return t
    }
}

/// The payload for an account transaction (only transfer is supported for now).
public enum AccountTransactionPayload: Serialize, Deserialize, FromGRPC, Equatable {
    case deployModule(_ module: WasmModule)
//    case initContract(amount: MicroCCDAmount, modRef: ModuleReference, initName: InitName, param: Parameter)
    // case updateContract
    case transfer(amount: MicroCCDAmount, receiver: AccountAddress, memo: Memo? = nil)
    // case addBaker
    // case removeBaker
    // case updateBakerStake
    // case updateBakerStakeEarnings
    // case updateBakerKeys
    // case updateCredentialKeys
    // case encryptedAmountTransfer(memo: Data?)
    // case transferToEncrypted
    // case transferToPublic
    case transferWithSchedule(receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo? = nil)
    // case updateCredentials
    // case registerData
    // case configureBaker
    // case configureDelegation

    var cost: Energy {
        switch self {
        case let .deployModule(module):
            return Energy(module.source.count) / 10
        case .transfer:
            return 300 // including memo doesn't increase cost
        case let .transferWithSchedule(_, schedule, _):
            return Energy(schedule.count) * (300 + 64) // including memo doesn't increase cost
        }
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0

        // Based on 'https://github.com/Concordium/concordium-base/blob/2c3255f39afd73543b5b21bbae1074fb069a0abd/rust-src/concordium_base/src/transactions.rs#L931'.
        switch self {
        case let .deployModule(module):
            res += buffer.writeInteger(0, as: UInt8.self)
            res += buffer.writeSerializable(module)
        case let .transfer(amount, receiver, memo):
            if let memo {
                res += buffer.writeInteger(22, as: UInt8.self)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(memo)
                res += buffer.writeInteger(amount)
            } else {
                res += buffer.writeInteger(3, as: UInt8.self)
                res += buffer.writeData(receiver.data)
                res += buffer.writeInteger(amount)
            }
        case let .transferWithSchedule(receiver, schedule, memo):
            if let memo {
                res += buffer.writeInteger(24, as: UInt8.self)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(memo)
                res += buffer.writeSerializable(list: schedule, lengthPrefix: UInt8.self)
            } else {
                res += buffer.writeInteger(19, as: UInt8.self)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(list: schedule, lengthPrefix: UInt8.self)
            }
        }

        return res
    }

    public static func deserialize(_ data: inout Cursor) -> AccountTransactionPayload? {
        guard let type = data.parseUInt(UInt8.self) else { return nil }

        switch type {
        case 0:
            guard let module = WasmModule.deserialize(&data) else { return nil }
            return AccountTransactionPayload.deployModule(module)
        case 3, 22:
            guard let receiver = AccountAddress.deserialize(&data) else { return nil }
            var memo: Memo?
            if type == 22 {
                guard let m = Memo.deserialize(&data) else { return nil }
                memo = m
            }
            guard let amount = data.parseUInt(UInt64.self) else { return nil }
            return .transfer(amount: amount, receiver: receiver, memo: memo)
        case 19, 24:
            guard let receiver = AccountAddress.deserialize(&data) else { return nil }
            var memo: Memo?
            if type == 24 {
                guard let m = Memo.deserialize(&data) else { return nil }
                memo = m
            }
            guard let length = data.parseUInt(UInt8.self) else { return nil }
            var schedule: [ScheduledTransfer] = []
            for _ in 0 ... length {
                guard let s = ScheduledTransfer.deserialize(&data) else { return nil }
                schedule.append(s)
            }
            return .transferWithSchedule(receiver: receiver, schedule: schedule, memo: memo)
        // TODO: handle the rest of the cases...
        default:
            // TODO: should this be an error instead?
            return nil
        }
    }

    static func fromGRPC(_ gRPC: Concordium_V2_AccountTransactionPayload) throws -> AccountTransactionPayload {
        guard let payload = gRPC.payload else {
            throw GRPCConversionError(message: "Expected a payload value on GRPC type")
        }
        switch payload {
        case let .deployModule(src):
            return try .deployModule(WasmModule.fromGRPC(src))
        case let .transfer(payload):
            return .transfer(amount: payload.amount.value, receiver: AccountAddress(payload.receiver.value))
        case let .transferWithMemo(payload):
            return try .transfer(amount: payload.amount.value, receiver: AccountAddress(payload.receiver.value), memo: Memo.fromGRPC(payload.memo))
        // TODO: implement the rest...
//        case let .initContract(payload):
//        case let .updateContract(payload):
//        case let .registerData(data):
//        case let .rawPayload(<#T##Data#>):

        // TODO: ... and remove this
        default:
            throw GRPCConversionError(message: "Conversion not implemented for \(payload)")
        }
    }
//
//    func toGRPC() -> Concordium_V2_AccountTransactionPayload {
//        var t = Concordium_V2_AccountTransactionPayload()
//        switch self {
//        case let .deployModule(module):
//            t.deployModule = module.toGRPC()
//        case let .transfer(amount, receiver, memo):
//            var a = Concordium_V2_Amount()
//            a.value = amount
//            var r = Concordium_V2_AccountAddress()
//            r.value = receiver.data
//            if let memo {
//                var m = Concordium_V2_Memo()
//                m.value = memo
//                var p = Concordium_V2_TransferWithMemoPayload()
//                p.receiver = r
//                p.memo = m
//                p.amount = a
//                var t = Concordium_V2_AccountTransactionPayload()
//                t.transferWithMemo = p
//            } else {
//                var p = Concordium_V2_TransferPayload()
//                p.receiver = r
//                p.amount = a
//                var t = Concordium_V2_AccountTransactionPayload()
//                t.transfer = p
//            }
//        case let .transferWithSchedule(receiver, schedule, memo):
//            if let memo {
//                var m = Concordium_V2_Memo()
//                m.value = memo
//                var p = Concordium_V2_()
//                p.receiver = r
//                p.memo = m
//                p.amount = a
//                var t = Concordium_V2_AccountTransactionPayload()
//                t.transferWithMemo = p
//            } else {
//                var p = Concordium_V2_TransferPayload()
//                p.receiver = r
//                p.amount = a
//                var t = Concordium_V2_AccountTransactionPayload()
//                t.transfer = p
//            }
//        }
//
//        return t
//
//    }
}

/// Header of an account transaction that contains basic data to check whether
/// the sender and the transaction are valid. The header is shared by all transaction types.
public struct AccountTransactionHeader: ToGRPC {
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

    func toGRPC() -> Concordium_V2_AccountTransactionHeader {
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

public extension AccountCredential {
    func prepareDeployment(expiry: TransactionTime) -> PreparedAccountCredentialDeployment {
        .init(credential: self, expiry: expiry)
    }
}

public struct PreparedAccountCredentialDeployment {
    public var credential: AccountCredential
    public var expiry: TransactionTime

    public var hash: Data {
        get throws {
            let hex = try accountCredentialDeploymentHashHex(
                credential: credential,
                expiryUnixSecs: expiry
            )
            return try Data(hex: hex)
        }
    }
}

public struct SignedAccountCredentialDeployment {
    public var deployment: PreparedAccountCredentialDeployment
    public var signatures: CredentialSignatures

    public init(deployment: PreparedAccountCredentialDeployment, signatures: CredentialSignatures) {
        self.deployment = deployment
        self.signatures = signatures
    }

    public func toCryptoType() -> SignedAccountCredential {
        .init(
            credential: deployment.credential,
            signaturesHex: signatures.mapValues { $0.hex }
        )
    }

    public func serialize() throws -> SerializedSignedAccountCredentialDeployment {
        let hex = try accountCredentialDeploymentSignedPayloadHex(credential: toCryptoType())
        return try .init(data: Data(hex: hex), expiry: deployment.expiry)
    }
}

public struct SerializedSignedAccountCredentialDeployment: ToGRPC {
    public var data: Data
    public var expiry: TransactionTime

    public init(data: Data, expiry: TransactionTime) {
        self.data = data
        self.expiry = expiry
    }

    func toGRPC() -> Concordium_V2_CredentialDeployment {
        var x = Concordium_V2_TransactionTime()
        x.value = expiry
        var d = Concordium_V2_CredentialDeployment()
        d.messageExpiry = x
        d.rawPayload = data
        return d
    }
}
