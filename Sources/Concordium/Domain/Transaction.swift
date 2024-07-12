import ConcordiumWalletCrypto
import CryptoKit
import Foundation
import NIO

public enum TransactionCost {
    /// Get the base transaction cost for any transaction
    /// - Parameter headerByteCount: The size of the header
    /// - Parameter payloadByteCount: The size of the payload
    /// - Parameter signatureCount: The number of signatures for the transaction
    public static func base(headerByteCount: Int, payloadByteCount: Int, signatureCount: Int) -> Energy {
        let energyPerByte = 1
        let energyPerSignature = 100
        let sizeCost = Energy(energyPerByte * (headerByteCount + payloadByteCount))
        let signatureCost = Energy(energyPerSignature * signatureCount)
        return sizeCost + signatureCost
    }

    /// The amount of additional energy required for a "transfer" transaction
    public static let TRANSFER: Energy = 300 // Including memo doesn't increase the cost
    /// The amount of additional energy required for a "transfer to public" transaction
    public static let TRANSFER_TO_PUBLIC: Energy = 14850

    /// The amount of additional energy required for a "transfer with schedule" transaction
    public static func transferWithSchedule(_ schedule: [ScheduledTransfer]) -> Energy {
        Energy(schedule.count) * (300 + 64) // including memo doesn't increase cost
    }

    /// The amount of additional energy required for a "deploy module" transaction
    public static func deployModule(_ module: WasmModule) -> Energy {
        Energy(module.source.count) / 10
    }

    /// The amount of additional energy required for a "init contract" transaction
    public static func initContract(maxEnergy: Energy) -> Energy {
        maxEnergy
    }

    /// The amount of additional energy required for a "update contract" transaction
    public static func updateContract(maxEnergy: Energy) -> Energy {
        maxEnergy
    }

    /// The amount of additional energy required for a "register data" transaction
    public static let REGISTER_DATA: Energy = 300

    public static func updateCredentialKeys(numCredentialsBefore: UInt16, numKeys: UInt16) -> Energy {
        500 * UInt64(numCredentialsBefore) + 100 * UInt64(numKeys)
    }

    public static func updateCredentials(numCredentialsBefore: UInt16, numKeys: [UInt16]) -> Energy {
        500 * UInt64(numCredentialsBefore) + 100 * numKeys.map { 54000 + 100 * UInt64($0) }.reduce(0, +)
    }

    public static func configureBaker(withKeys hasKeys: Bool) -> Energy {
        hasKeys ? 4050 : 300
    }

    public static let CONFIGURE_DELEGATION: Energy = 300
}

/// Represents an account transaction consisting of the transaction components necessary for submission
public struct AccountTransaction {
    /// The sender account
    public var sender: AccountAddress
    /// The transaction payload
    public let payload: AccountTransactionPayload
    /// The amount of energy required for the transaction
    public let energy: Energy

    public init(sender: AccountAddress, payload: AccountTransactionPayload, energy: Energy) {
        self.sender = sender
        self.payload = payload
        self.energy = energy
    }

    /// Creates a transaction for a deploying smart contract module
    public static func deployModule(sender: AccountAddress, module: WasmModule) -> Self {
        let payload = AccountTransactionPayload.deployModule(module)
        let energy = TransactionCost.deployModule(module)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for transferring CCD from one account to another, with an optional memo
    public static func transfer(sender: AccountAddress, receiver: AccountAddress, amount: MicroCCDAmount, memo: Memo? = nil) -> Self {
        let payload = AccountTransactionPayload.transfer(amount: amount, receiver: receiver, memo: memo)
        return self.init(sender: sender, payload: payload, energy: TransactionCost.TRANSFER)
    }

    /// Creates a transaction for transferring CCD with a release schedule from one account to another, with an optional memo
    public static func transferWithSchedule(sender: AccountAddress, receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo?) -> Self {
        let payload = AccountTransactionPayload.transferWithSchedule(receiver: receiver, schedule: schedule, memo: memo)
        let energy = TransactionCost.transferWithSchedule(schedule)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for initializing a smart contract from a given module reference.
    /// - Parameter maxEnergy: the max amount of energy to spend for the corresponding init function of the smart contract module. If this is not enough to execute the transaction on the node, the transaction will be rejected.
    public static func initContract(sender: AccountAddress, amount: MicroCCDAmount, modRef: ModuleReference, initName: InitName, param: Parameter, maxEnergy: Energy) -> Self {
        let payload = AccountTransactionPayload.initContract(amount: amount, modRef: modRef, initName: initName, param: param)
        let energy = TransactionCost.initContract(maxEnergy: maxEnergy)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for invoking a smart contract entrypoint
    /// - Parameter maxEnergy: the max amount of energy to spend for the corresponding receive function of the smart contract module. If this is not enough to execute the transaction on the node, the transaction will be rejected.
    public static func updateContract(sender: AccountAddress, amount: MicroCCDAmount, contractAddress: ContractAddress, receiveName: ReceiveName, param: Parameter, maxEnergy: Energy) -> Self {
        let payload = AccountTransactionPayload.updateContract(amount: amount, address: contractAddress, receiveName: receiveName, message: param)
        let energy = TransactionCost.updateContract(maxEnergy: maxEnergy)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for registering data on chain
    public static func registerData(sender: AccountAddress, data: RegisteredData) -> Self {
        let payload = AccountTransactionPayload.registerData(data)
        return self.init(sender: sender, payload: payload, energy: TransactionCost.REGISTER_DATA)
    }

    /// Creates a transaction for transferring CCD from shielded to public balance. Returns `nil` if the data could for the transaction could not be successfully created
    public static func transferToPublic(sender: AccountAddress, global: GlobalContext, senderSecretKey: String, inputAmount: InputEncryptedAmount, toTransfer: MicroCCDAmount) -> Self? {
        guard let data = try? secToPubTransferData(ctx: global, senderSecretKey: senderSecretKey, inputAmount: inputAmount, toTransfer: toTransfer) else { return nil }
        let payload = AccountTransactionPayload.transferToPublic(data)
        return self.init(sender: sender, payload: payload, energy: TransactionCost.TRANSFER_TO_PUBLIC)
    }

    /// Creates a transaction for updating the keys of a credential corresponding to the given ``CredentialRegistrationID``
    public static func updateCredentialKeys(sender: AccountAddress, numExistingCredentials: UInt16, credId: CredentialRegistrationID, keys: CredentialPublicKeys) -> Self {
        let payload = AccountTransactionPayload.updateCredentialKeys(credId: credId, keys: keys)
        let energy = TransactionCost.updateCredentialKeys(numCredentialsBefore: numExistingCredentials, numKeys: UInt16(keys.keys.count))
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for updating the credentials of the `sender` account
    public static func updateCredentials(sender: AccountAddress, numExistingCredentials: UInt16, newCredentials: [CredentialIndex: CredentialDeploymentInfo], removeCredentials: [CredentialRegistrationID], newThreshold: UInt8) -> Self {
        let payload = AccountTransactionPayload.updateCredentials(newCredInfos: newCredentials, removeCredIds: removeCredentials, newThreshold: newThreshold)
        let numKeys = newCredentials.values.map { UInt16($0.credentialPublicKeys.keys.count) }
        let energy = TransactionCost.updateCredentials(numCredentialsBefore: numExistingCredentials, numKeys: numKeys)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    public static func configureBaker(sender: AccountAddress, payload: ConfigureBakerPayload) -> Self {
        let p = AccountTransactionPayload.configureBaker(payload)
        let energy = TransactionCost.configureBaker(withKeys: payload.keys_with_proofs != nil)
        return self.init(sender: sender, payload: p, energy: energy)
    }

    /// Prepares the transaction for submission
    /// - Parameter sequenceNumber: The next sequence number (aka "nonce") for the account
    /// - Parameter expiry: The transaction expiry in seconds since unix epoch
    /// - Parameter signatureCount: the number of signatures the transaction will be signed with
    public func prepare(sequenceNumber: SequenceNumber, expiry: TransactionTime, signatureCount: Int) -> PreparedAccountTransaction {
        let serializedPayload = payload.serialize()
        // While the header size is fixed at the moment, it isn't guaranteed to stay true in the future.
        // As the cost depends on this size, we first create the header with no energy allocated.
        // We then serialize this header and patch the computed cost back on.
        // Updating the energy allocation will never affect the header size.
        var header = AccountTransactionHeader(sender: sender, sequenceNumber: sequenceNumber, maxEnergy: 0, expiry: expiry)
        header.maxEnergy = TransactionCost.base(
            headerByteCount: header.serialize(serializedPayloadSize: 0).count, // concrete payload size doesn't affect header size
            payloadByteCount: serializedPayload.count,
            signatureCount: signatureCount
        ) + energy
        return .init(header: header, serializedPayload: serializedPayload)
    }
}

public struct PreparedAccountTransaction {
    /// The transaction header
    public var header: AccountTransactionHeader
    /// The serialized `AccountTransactionPayload`
    public var serializedPayload: Data

    /// Serializes the transaction into the provided `ByteBuffer`
    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += header.serializeInto(buffer: &buffer, serializedPayloadSize: UInt32(serializedPayload.count))
        res += buffer.writeData(serializedPayload)
        return res
    }

    /// Serializes the transaction
    public func serialize() -> SerializedAccountTransaction {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf)
        let data = Data(buffer: buf)
        return .init(data: data)
    }
}

/// Represents a serialized account transaction
public struct SerializedAccountTransaction {
    /// The inner data
    public var data: Data

    public init(data: Data) {
        self.data = data
    }

    /// A SHA256 hash of `data`
    public var hash: Data {
        Data(SHA256.hash(data: data))
    }
}

/// A map of signatures for an account
public typealias Signatures = [CredentialIndex: CredentialSignatures]
/// A map of signatures for a credential
public typealias CredentialSignatures = [KeyIndex: Data]

/// A signed transaction to be sent to a Concordium node
public struct SignedAccountTransaction: ToGRPC {
    /// The transaction to send
    public var transaction: PreparedAccountTransaction
    /// The signatures on the transaction
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

/// Describes the different transaction types available
public enum TransactionType: UInt8, Serialize, Deserialize {
    case deployModule = 0
    case initContract = 1
    case updateContract = 2
    case transfer = 3
    /// Only effective prior to protocol version 4
    case addBaker = 4
    /// Only effective prior to protocol version 4
    case removeBaker = 5
    /// Only effective prior to protocol version 4
    case updateBakerStake = 6
    /// Only effective prior to protocol version 4
    case updateBakerRestakeEarnings = 7
    /// Only effective prior to protocol version 4
    case updateBakerKeys = 8
    case updateCredentialKeys = 13
    /// Only effective prior to protocol version 7
    case encryptedAmountTransfer = 16
    /// Only effective prior to protocol version 7
    case transferToEncrypted = 17
    case transferToPublic = 18
    case transferWithSchedule = 19
    case updateCredentials = 20
    case registerData = 21
    case transferWithMemo = 22
    /// Only effective prior to protocol version 7
    case encryptedAmountTransferWithMemo = 23
    case transferWithScheduleAndMemo = 24
    /// Effective from protocol version 4
    case configureBaker = 25
    /// Effective from protocol version 4
    case configureDelegation = 26

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(rawValue)
    }

    public static func deserialize(_ data: inout Cursor) -> TransactionType? {
        guard let tag = data.parseUInt(UInt8.self), let type = TransactionType(rawValue: tag) else { return nil }
        return type
    }
}

extension UpdateCredentialsPayload: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> ConcordiumWalletCrypto.UpdateCredentialsPayload? {
        guard let result = try? deserializeUpdateCredentialsPayload(bytes: data.remaining) else { return nil }
        data.advance(by: result.bytesRead)
        return result.value
    }
}

extension SecToPubTransferData: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> ConcordiumWalletCrypto.SecToPubTransferData? {
        guard let result = try? deserializeSecToPubTransferData(bytes: data.remaining) else { return nil }
        data.advance(by: result.bytesRead)
        return result.value
    }
}

public struct ConfigureBakerPayload: Equatable, Serialize, Deserialize {
    /// The equity capital of the baker
    public let capital: MicroCCDAmount?
    /// Whether the baker's earnings are restaked
    public let restakeEarnings: Bool?
    /// Whether the pool is open for delegators
    public let open_for_delegation: OpenStatus?
    /// The key/proof pairs to verify the baker.
    public let keys_with_proofs: BakerKeysPayload?
    /// The URL referencing the baker's metadata.
    public let metadata_url: String? // At most 2048 bytes
    /// The commission the pool owner takes on transaction fees.
    public let transaction_fee_commission: AmountFraction?
    /// The commission the pool owner takes on baking rewards.
    public let baking_reward_commission: AmountFraction?
    /// The commission the pool owner takes on finalization rewards.
    public let finalization_reward_commission: AmountFraction?
}

/// The payload for an account transaction. Only contains payloads valid from protocol version 7
public enum AccountTransactionPayload: Serialize, Deserialize, FromGRPC, ToGRPC, Equatable {
    case deployModule(_ module: WasmModule)
    case initContract(amount: MicroCCDAmount, modRef: ModuleReference, initName: InitName, param: Parameter)
    case updateContract(amount: MicroCCDAmount, address: ContractAddress, receiveName: ReceiveName, message: Parameter)
    case transfer(amount: MicroCCDAmount, receiver: AccountAddress, memo: Memo? = nil)
    case updateCredentialKeys(credId: CredentialRegistrationID, keys: CredentialPublicKeys)
    case transferToPublic(_ data: SecToPubTransferData)
    case transferWithSchedule(receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo? = nil)
    case updateCredentials(newCredInfos: [CredentialIndex: CredentialDeploymentInfo], removeCredIds: [CredentialRegistrationID], newThreshold: UInt8)
    case registerData(_ data: RegisteredData)
    case configureBaker(_ data: ConfigureBakerPayload)
    // case configureDelegation

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0

        // Based on 'https://github.com/Concordium/concordium-base/blob/2c3255f39afd73543b5b21bbae1074fb069a0abd/rust-src/concordium_base/src/transactions.rs#L931'.
        switch self {
        case let .deployModule(module):
            res += buffer.writeSerializable(TransactionType.deployModule)
            res += buffer.writeSerializable(module)
        case let .initContract(amount, modRef, initName, param):
            res += buffer.writeSerializable(TransactionType.initContract)
            res += buffer.writeInteger(amount)
            res += buffer.writeSerializable(modRef)
            res += buffer.writeSerializable(initName)
            res += buffer.writeSerializable(param)
        case let .updateContract(amount, contractAddress, receiveName, param):
            res += buffer.writeSerializable(TransactionType.updateContract)
            res += buffer.writeInteger(amount)
            res += buffer.writeSerializable(contractAddress)
            res += buffer.writeSerializable(receiveName)
            res += buffer.writeSerializable(param)
        case let .transfer(amount, receiver, memo):
            if let memo {
                res += buffer.writeSerializable(TransactionType.transferWithMemo)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(memo)
                res += buffer.writeInteger(amount)
            } else {
                res += buffer.writeSerializable(TransactionType.transfer)
                res += buffer.writeData(receiver.data)
                res += buffer.writeInteger(amount)
            }
        case let .updateCredentialKeys(credId, keys):
            res += buffer.writeSerializable(TransactionType.updateCredentialKeys)
            res += buffer.writeSerializable(credId)
            res += buffer.writeSerializable(keys)
        case let .transferToPublic(data):
            res += buffer.writeSerializable(TransactionType.transferToPublic)
            res += buffer.writeData(Data(data.serializedRemainingAmount))
            res += buffer.writeInteger(data.transferAmount)
            res += buffer.writeInteger(data.index)
            res += buffer.writeData(Data(data.serializedProof))
        case let .transferWithSchedule(receiver, schedule, memo):
            if let memo {
                res += buffer.writeSerializable(TransactionType.transferWithScheduleAndMemo)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(memo)
                res += buffer.writeSerializable(list: schedule, lengthPrefix: UInt8.self)
            } else {
                res += buffer.writeSerializable(TransactionType.transferWithSchedule)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(list: schedule, lengthPrefix: UInt8.self)
            }
        case let .updateCredentials(newCredInfos, removeCredIds, newThreshold):
            res += buffer.writeSerializable(TransactionType.updateCredentials)
            res += buffer.writeSerializable(map: newCredInfos, lengthPrefix: UInt64.self)
            res += buffer.writeSerializable(list: removeCredIds, lengthPrefix: UInt64.self)
            res += buffer.writeInteger(newThreshold)
        case let .registerData(data):
            res += buffer.writeSerializable(TransactionType.registerData)
            res += buffer.writeSerializable(data)
        case let .configureBaker(data):
            res += buffer.writeSerializable(TransactionType.configureBaker)
            res += buffer.writeSerializable(data)
        }

        return res
    }

    public static func deserialize(_ data: inout Cursor) -> AccountTransactionPayload? {
        guard let type = TransactionType.deserialize(&data) else { return nil }

        switch type {
        case .deployModule:
            guard let module = WasmModule.deserialize(&data) else { return nil }
            return AccountTransactionPayload.deployModule(module)
        case .initContract:
            guard let amount = data.parseUInt(MicroCCDAmount.self),
                  let modRef = ModuleReference.deserialize(&data),
                  let initName = InitName.deserialize(&data),
                  let param = Parameter.deserialize(&data) else { return nil }
            return AccountTransactionPayload.initContract(amount: amount, modRef: modRef, initName: initName, param: param)
        case .updateContract:
            guard let amount = data.parseUInt(MicroCCDAmount.self),
                  let contractAddress = ContractAddress.deserialize(&data),
                  let receiveName = ReceiveName.deserialize(&data),
                  let message = Parameter.deserialize(&data) else { return nil }
            return AccountTransactionPayload.updateContract(amount: amount, address: contractAddress, receiveName: receiveName, message: message)
        case .transfer:
            guard let receiver = AccountAddress.deserialize(&data),
                  let amount = data.parseUInt(UInt64.self) else { return nil }
            return .transfer(amount: amount, receiver: receiver)
        case .updateCredentialKeys:
            guard let credId = CredentialRegistrationID.deserialize(&data),
                  let keys = CredentialPublicKeys.deserialize(&data) else { return nil }
            return .updateCredentialKeys(credId: credId, keys: keys)
        case .transferToPublic:
            guard let transferData = SecToPubTransferData.deserialize(&data) else { return nil }
            return .transferToPublic(transferData)
        case .transferWithSchedule:
            guard let receiver = AccountAddress.deserialize(&data),
                  let schedule = data.deserialize(listOf: ScheduledTransfer.self, lengthPrefix: UInt8.self) else { return nil }
            return .transferWithSchedule(receiver: receiver, schedule: schedule)
        case .updateCredentials:
            guard let data = UpdateCredentialsPayload.deserialize(&data),
                  let removeCredIds = try? data.removeCredIds.map({ try CredentialRegistrationID($0) }) else { return nil }
            return .updateCredentials(newCredInfos: data.newCredInfos, removeCredIds: removeCredIds, newThreshold: data.newThreshold)
        case .registerData:
            guard let regData = RegisteredData.deserialize(&data) else { return nil }
            return .registerData(regData)
        case .transferWithMemo:
            guard let receiver = AccountAddress.deserialize(&data),
                  let memo = Memo.deserialize(&data),
                  let amount = data.parseUInt(UInt64.self) else { return nil }
            return .transfer(amount: amount, receiver: receiver, memo: memo)
        case .transferWithScheduleAndMemo:
            guard let receiver = AccountAddress.deserialize(&data),
                  let memo = Memo.deserialize(&data),
                  let schedule = data.deserialize(listOf: ScheduledTransfer.self, lengthPrefix: UInt8.self) else { return nil }
            return .transferWithSchedule(receiver: receiver, schedule: schedule, memo: memo)
        case .configureBaker:
            guard let payload = ConfigureBakerPayload.deserialize(&data) else { return nil }
            return .configureBaker(payload)
        case .configureDelegation:
            return nil // TODO: missing impl
        case .addBaker, .removeBaker, .updateBakerStake, .updateBakerRestakeEarnings, .updateBakerKeys:
            return nil // Not supported, invalid since protocol version 4
        case .encryptedAmountTransfer, .encryptedAmountTransferWithMemo, .transferToEncrypted:
            return nil // Not supported, invalid since protocol version 7
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
            return .transfer(amount: payload.amount.value, receiver: AccountAddress.fromGRPC(payload.receiver))
        case let .transferWithMemo(payload):
            return try .transfer(amount: payload.amount.value, receiver: AccountAddress.fromGRPC(payload.receiver), memo: Memo.fromGRPC(payload.memo))
        case let .initContract(payload):
            return try .initContract(amount: payload.amount.value, modRef: ModuleReference.fromGRPC(payload.moduleRef), initName: InitName.fromGRPC(payload.initName), param: Parameter.fromGRPC(payload.parameter))
        case let .updateContract(payload):
            return try .updateContract(amount: payload.amount.value, address: ContractAddress.fromGRPC(payload.address), receiveName: ReceiveName.fromGRPC(payload.receiveName), message: Parameter.fromGRPC(payload.parameter))
        case let .registerData(data):
            return try .registerData(RegisteredData.fromGRPC(data))
        case let .rawPayload(data):
            guard let payload = Self.deserialize(data) else { throw GRPCConversionError(message: "Failed to deserialize raw payload") }
            return payload
        }
    }

    func toGRPC() -> Concordium_V2_AccountTransactionPayload {
        var t = Concordium_V2_AccountTransactionPayload()
        t.rawPayload = serialize()
        return t
    }
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
    /// Prepare an account credential for deployment
    func prepareDeployment(expiry: TransactionTime) -> PreparedAccountCredentialDeployment {
        .init(credential: self, expiry: expiry)
    }
}

/// An account credential prepared for deployment
public struct PreparedAccountCredentialDeployment {
    /// The account credential to deploy
    public var credential: AccountCredential
    /// The transaction expiry in seconds from unix epoch
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

/// An account credential ready for deployment with signatures
public struct SignedAccountCredentialDeployment {
    /// The prepared account credential deployment
    public var deployment: PreparedAccountCredentialDeployment
    /// The signatures for the deployment
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

    /// Serializes the account credential deployment
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
