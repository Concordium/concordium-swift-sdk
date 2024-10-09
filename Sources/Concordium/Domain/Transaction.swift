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

    /// The amount of additional energy required for a "update credential keys" transaction
    public static func updateCredentialKeys(numCredentialsBefore: UInt16, numKeys: UInt16) -> Energy {
        500 * UInt64(numCredentialsBefore) + 100 * UInt64(numKeys)
    }

    /// The amount of additional energy required for a "update credentials" transaction
    public static func updateCredentials(numCredentialsBefore: UInt16, numKeys: [UInt16]) -> Energy {
        500 * UInt64(numCredentialsBefore) + 100 * numKeys.map { 54000 + 100 * UInt64($0) }.reduce(0, +)
    }

    /// The amount of additional energy required for a "configure baker" transaction
    public static func configureBaker(withKeys hasKeys: Bool) -> Energy {
        hasKeys ? 4050 : 300
    }

    /// The amount of additional energy required for a "configure delegation" transaction
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
    public static func transfer(sender: AccountAddress, receiver: AccountAddress, amount: CCD, memo: Memo? = nil) -> Self {
        let payload = AccountTransactionPayload.transfer(amount: amount, receiver: receiver, memo: memo)
        return self.init(sender: sender, payload: payload, energy: TransactionCost.TRANSFER)
    }

    /// Creates a transaction for transferring CCD with a release schedule from one account to another, with an optional memo
    public static func transferWithSchedule(sender: AccountAddress, receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo? = nil) -> Self {
        let payload = AccountTransactionPayload.transferWithSchedule(receiver: receiver, schedule: schedule, memo: memo)
        let energy = TransactionCost.transferWithSchedule(schedule)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for initializing a smart contract from a given module reference.
    /// - Parameter maxEnergy: the max amount of energy to spend for the corresponding init function of the smart contract module. If this is not enough to execute the transaction on the node, the transaction will be rejected.
    public static func initContract(sender: AccountAddress, amount: CCD, modRef: ModuleReference, initName: InitName, param: Parameter, maxEnergy: Energy) -> Self {
        let payload = AccountTransactionPayload.initContract(amount: amount, modRef: modRef, initName: initName, param: param)
        let energy = TransactionCost.initContract(maxEnergy: maxEnergy)
        return self.init(sender: sender, payload: payload, energy: energy)
    }

    /// Creates a transaction for invoking a smart contract entrypoint
    /// - Parameter maxEnergy: the max amount of energy to spend for the corresponding receive function of the smart contract module. If this is not enough to execute the transaction on the node, the transaction will be rejected.
    public static func updateContract(sender: AccountAddress, amount: CCD, contractAddress: ContractAddress, receiveName: ReceiveName, param: Parameter, maxEnergy: Energy) -> Self {
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
    public static func transferToPublic(sender: AccountAddress, global: GlobalContext, senderSecretKey: Data, inputAmount: InputEncryptedAmount, toTransfer: CCD) -> Self? {
        guard let data = try? SecToPubTransferData(ctx: global, senderSecretKey: senderSecretKey, inputAmount: inputAmount, toTransfer: toTransfer) else { return nil }
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

    /// Creates a transaction for configuring the sender as a baker
    public static func configureBaker(sender: AccountAddress, payload: ConfigureBakerPayload) -> Self {
        let p = AccountTransactionPayload.configureBaker(payload)
        let energy = TransactionCost.configureBaker(withKeys: payload.keysWithProofs != nil)
        return self.init(sender: sender, payload: p, energy: energy)
    }

    /// Creates a transaction for configuring the sender as a baker
    public static func configureBaker(sender: AccountAddress, capital: CCD? = nil, restakeEarnings: Bool? = nil, openForDelegation: OpenStatus? = nil, bakerKeys: BakerKeyPairs? = nil, metadataUrl: String? = nil, transactionFeeCommission: AmountFraction? = nil, bakingRewardCommission: AmountFraction? = nil, finalizationRewardCommission: AmountFraction? = nil) -> Self {
        let keysWithProofs = try? bakerKeys.map { try BakerKeysPayload.create(account: sender, bakerKeys: $0) }
        let payload = ConfigureBakerPayload(capital: capital, restakeEarnings: restakeEarnings, openForDelegation: openForDelegation, keysWithProofs: keysWithProofs, metadataUrl: metadataUrl, transactionFeeCommission: transactionFeeCommission, bakingRewardCommission: bakingRewardCommission, finalizationRewardCommission: finalizationRewardCommission)
        return configureBaker(sender: sender, payload: payload)
    }

    /// Creates a transaction for configuring the sender as a delegator.
    public static func configureDelegation(sender: AccountAddress, payload: ConfigureDelegationPayload) -> Self {
        let p = AccountTransactionPayload.configureDelegation(payload)
        return self.init(sender: sender, payload: p, energy: TransactionCost.CONFIGURE_DELEGATION)
    }

    /// Creates a transaction for configuring the sender as a delegator
    public static func configureDelegation(sender: AccountAddress, capital: CCD? = nil, restakeEarnings: Bool? = nil, delegationTarget: DelegationTarget? = nil) -> Self {
        let payload = ConfigureDelegationPayload(capital: capital, restakeEarnings: restakeEarnings, delegationTarget: delegationTarget)
        return configureDelegation(sender: sender, payload: payload)
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

/// A signed transaction to be sent to a Concordium node.
///
/// Typically, this is not created directly, but rather by passing a ``AccountTransaction`` to a ``Signer``:
/// ```swift
/// let signer: any Signer = AccountKeysCurve25519(...)
/// let transaction: AccountTransaction = ...
/// let signed: SignedAccountTransaction = signer.sign(transaction) // This can now be sent with any ``NodeClient``
/// ```
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
        s.signatures = signatures.reduce(into: [:]) { res, v in
            var m = Concordium_V2_AccountSignatureMap()
            m.signatures = v.value.reduce(into: [:]) { res, e in
                var s = Concordium_V2_Signature()
                s.value = e.value
                res[UInt32(e.key)] = s
            }
            res[UInt32(v.key)] = m
        }

        var t = Concordium_V2_AccountTransaction()
        t.header = transaction.header.toGRPC()
        t.payload = p
        t.signature = s
        return t
    }
}

/// Describes the different transaction types available as strings
enum TransactionTypeString: String, Codable {
    case deployModule
    case initContract
    case update
    case transfer
    /// Only effective prior to protocol version 4
    case addBaker
    /// Only effective prior to protocol version 4
    case removeBaker
    /// Only effective prior to protocol version 4
    case updateBakerStake
    /// Only effective prior to protocol version 4
    case updateBakerRestakeEarnings
    /// Only effective prior to protocol version 4
    case updateBakerKeys
    case updateCredentialKeys
    /// Only effective prior to protocol version 7
    case encryptedAmountTransfer
    /// Only effective prior to protocol version 7
    case transferToEncrypted
    case transferToPublic
    case transferWithSchedule
    case updateCredentials
    case registerData
    case transferWithMemo
    /// Only effective prior to protocol version 7
    case encryptedAmountTransferWithMemo
    case transferWithScheduleAndMemo
    /// Effective from protocol version 4
    case configureBaker
    /// Effective from protocol version 4
    case configureDelegation

    init(type: TransactionType) {
        switch type {
        case .deployModule:
            self = .deployModule
        case .initContract:
            self = .initContract
        case .update:
            self = .update
        case .transfer:
            self = .transfer
        case .addBaker:
            self = .addBaker
        case .removeBaker:
            self = .removeBaker
        case .updateBakerStake:
            self = .updateBakerStake
        case .updateBakerRestakeEarnings:
            self = .updateBakerRestakeEarnings
        case .updateBakerKeys:
            self = .updateBakerKeys
        case .updateCredentialKeys:
            self = .updateCredentialKeys
        case .encryptedAmountTransfer:
            self = .encryptedAmountTransfer
        case .transferToEncrypted:
            self = .transferToEncrypted
        case .transferToPublic:
            self = .transferToPublic
        case .transferWithSchedule:
            self = .transferWithSchedule
        case .updateCredentials:
            self = .updateCredentials
        case .registerData:
            self = .registerData
        case .transferWithMemo:
            self = .transferWithMemo
        case .encryptedAmountTransferWithMemo:
            self = .encryptedAmountTransferWithMemo
        case .transferWithScheduleAndMemo:
            self = .transferWithScheduleAndMemo
        case .configureBaker:
            self = .configureBaker
        case .configureDelegation:
            self = .configureDelegation
        }
    }

    var transactionType: TransactionType {
        switch self {
        case .deployModule:
            return .deployModule
        case .initContract:
            return .initContract
        case .update:
            return .update
        case .transfer:
            return .transfer
        case .addBaker:
            return .addBaker
        case .removeBaker:
            return .removeBaker
        case .updateBakerStake:
            return .updateBakerStake
        case .updateBakerRestakeEarnings:
            return .updateBakerRestakeEarnings
        case .updateBakerKeys:
            return .updateBakerKeys
        case .updateCredentialKeys:
            return .updateCredentialKeys
        case .encryptedAmountTransfer:
            return .encryptedAmountTransfer
        case .transferToEncrypted:
            return .transferToEncrypted
        case .transferToPublic:
            return .transferToPublic
        case .transferWithSchedule:
            return .transferWithSchedule
        case .updateCredentials:
            return .updateCredentials
        case .registerData:
            return .registerData
        case .transferWithMemo:
            return .transferWithMemo
        case .encryptedAmountTransferWithMemo:
            return .encryptedAmountTransferWithMemo
        case .transferWithScheduleAndMemo:
            return .transferWithScheduleAndMemo
        case .configureBaker:
            return .configureBaker
        case .configureDelegation:
            return .configureDelegation
        }
    }
}

/// Describes the different transaction types available. The values of these are used when serializing transactions
/// and as such need to match the values expected by the node.
public enum TransactionType: UInt8, Serialize, Deserialize, Codable {
    case deployModule = 0
    case initContract = 1
    case update = 2
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

    public init(from decoder: any Decoder) throws {
        self = try TransactionTypeString(from: decoder).transactionType
    }

    public func encode(to encoder: any Encoder) throws {
        try TransactionTypeString(type: self).encode(to: encoder)
    }
}

extension TransactionType: FromGRPC {
    typealias GRPC = Concordium_V2_TransactionType

    static func fromGRPC(_ g: GRPC) throws -> TransactionType {
        switch g {
        case .deployModule: return .deployModule
        case .initContract: return .initContract
        case .update: return .update
        case .transfer: return .transfer
        case .addBaker: return .addBaker
        case .removeBaker: return .removeBaker
        case .updateBakerStake: return .updateBakerStake
        case .updateBakerRestakeEarnings: return .updateBakerRestakeEarnings
        case .updateBakerKeys: return .updateBakerKeys
        case .updateCredentialKeys: return .updateCredentialKeys
        case .encryptedAmountTransfer: return .encryptedAmountTransfer
        case .transferToEncrypted: return .transferToEncrypted
        case .transferToPublic: return .transferToPublic
        case .transferWithSchedule: return .transferWithSchedule
        case .updateCredentials: return .updateCredentials
        case .registerData: return .registerData
        case .transferWithMemo: return .transferWithMemo
        case .encryptedAmountTransferWithMemo: return .encryptedAmountTransferWithMemo
        case .transferWithScheduleAndMemo: return .transferWithScheduleAndMemo
        case .configureBaker: return .configureBaker
        case .configureDelegation: return .configureDelegation
        case .UNRECOGNIZED: throw GRPCError.valueOutOfBounds
        }
    }
}

extension UpdateCredentialsPayload: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> ConcordiumWalletCrypto.UpdateCredentialsPayload? {
//        let result = try! deserializeUpdateCredentialsPayload(bytes: data.remaining)
        guard let result = try? deserializeUpdateCredentialsPayload(bytes: data.remaining) else { return nil }
        data.advance(by: result.bytesRead)
        return result.value
    }
}

public struct SecToPubTransferData: Equatable {
    /**
     * The serialized remaining amount after deducting the amount to transfer
     * Serialized according to the [`Serial`] implementation of [`concordium_base::encrypted_transfers::types::EncryptedAmount`]
     */
    public var remainingAmount: Data
    /**
     * The amount to transfer
     */
    public var transferAmount: CCD
    /**
     * The transfer index of the transfer
     */
    public var index: UInt64
    /**
     * The serialized proof that the transfer is correct.
     * Serialized according to the [`Serial`] implementation of [`concordium_base::encrypted_transfers::types::SecToPubAmountTransferProof`]
     */
    public var proof: Data

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(
        /**
         * The serialized remaining amount after deducting the amount to transfer
         * Serialized according to the [`Serial`] implementation of [`concordium_base::encrypted_transfers::types::EncryptedAmount`]
         */
        remainingAmount: Data,
        /**
            * The amount to transfer
            */
        transferAmount: CCD,
        /**
            * The transfer index of the transfer
            */
        index: UInt64,
        /**
            * The serialized proof that the transfer is correct.
            * Serialized according to the [`Serial`] implementation of [`concordium_base::encrypted_transfers::types::SecToPubAmountTransferProof`]
            */
        proof: Data
    ) {
        self.remainingAmount = remainingAmount
        self.transferAmount = transferAmount
        self.index = index
        self.proof = proof
    }

    init(fromCryptoType cryptoType: ConcordiumWalletCrypto.SecToPubTransferData) {
        remainingAmount = cryptoType.remainingAmount
        transferAmount = CCD(microCCD: cryptoType.transferAmount)
        index = cryptoType.index
        proof = cryptoType.proof
    }

    init(ctx: GlobalContext, senderSecretKey: Bytes, inputAmount: InputEncryptedAmount, toTransfer: CCD) throws {
        let cryptoType = try secToPubTransferData(ctx: ctx, senderSecretKey: senderSecretKey, inputAmount: inputAmount, toTransfer: toTransfer.microCCD)
        self.init(fromCryptoType: cryptoType)
    }
}

extension SecToPubTransferData: Deserialize, Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeData(remainingAmount)
        res += buffer.writeSerializable(transferAmount)
        res += buffer.writeInteger(index)
        res += buffer.writeData(proof)
        return res
    }

    public static func deserialize(_ data: inout Cursor) -> SecToPubTransferData? {
        guard let result = try? deserializeSecToPubTransferData(bytes: data.remaining) else { return nil }
        data.advance(by: result.bytesRead)
        return .init(fromCryptoType: result.value)
    }
}

extension SecToPubTransferData: Codable {
    private enum CodingKeys: String, CodingKey {
        case remainingAmount
        case transferAmount
        case index
        case proof
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        remainingAmount = try Data(hex: container.decode(String.self, forKey: .remainingAmount))
        transferAmount = try container.decode(CCD.self, forKey: .transferAmount)
        index = try container.decode(UInt64.self, forKey: .index)
        proof = try Data(hex: container.decode(String.self, forKey: .proof))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(remainingAmount.hex, forKey: .remainingAmount)
        try container.encode(transferAmount, forKey: .transferAmount)
        try container.encode(index, forKey: .index)
        try container.encode(proof.hex, forKey: .proof)
    }
}

public typealias BakerKeysPayload = ConcordiumWalletCrypto.BakerKeysPayload

extension BakerKeysPayload: Serialize, Deserialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(electionVerifyKey) + buffer.writeData(proofElection) + buffer.writeData(signatureVerifyKey) + buffer.writeData(proofSig) + buffer.writeData(aggregationVerifyKey) + buffer.writeData(proofAggregation)
    }

    public static func deserialize(_ data: inout Cursor) -> ConcordiumWalletCrypto.BakerKeysPayload? {
        guard let electionVerifyKey = data.read(num: 32 as UInt),
              let proofElection = data.read(num: 64 as UInt),
              let signatureVerifyKey = data.read(num: 32 as UInt),
              let proofSig = data.read(num: 64 as UInt),
              let aggregationVerifyKey = data.read(num: 96 as UInt),
              let proofAggregation = data.read(num: 64 as UInt) else { return nil }

        return Self(signatureVerifyKey: signatureVerifyKey, electionVerifyKey: electionVerifyKey, aggregationVerifyKey: aggregationVerifyKey, proofSig: proofSig, proofElection: proofElection, proofAggregation: proofAggregation)
    }

    /// Create a baker keys payload from a set of baker keys and the account the should be deployed for
    public static func create(account: AccountAddress, bakerKeys: BakerKeyPairs) throws -> Self {
        try makeConfigureBakerKeysPayload(accountBase58: account.base58Check, bakerKeys: bakerKeys)
    }
}

extension BakerKeysPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case signatureVerifyKey
        case electionVerifyKey
        case aggregationVerifyKey
        case proofSig
        case proofElection
        case proofAggregation
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(signatureVerifyKey.hex, forKey: .signatureVerifyKey)
        try container.encode(electionVerifyKey.hex, forKey: .electionVerifyKey)
        try container.encode(aggregationVerifyKey.hex, forKey: .aggregationVerifyKey)
        try container.encode(proofSig.hex, forKey: .proofSig)
        try container.encode(proofElection.hex, forKey: .proofElection)
        try container.encode(proofAggregation.hex, forKey: .proofAggregation)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)

        let signatureVerifyKey = try Data(hex: container.decode(String.self, forKey: .signatureVerifyKey))
        let electionVerifyKey = try Data(hex: container.decode(String.self, forKey: .electionVerifyKey))
        let aggregationVerifyKey = try Data(hex: container.decode(String.self, forKey: .aggregationVerifyKey))
        let proofSig = try Data(hex: container.decode(String.self, forKey: .proofSig))
        let proofElection = try Data(hex: container.decode(String.self, forKey: .proofElection))
        let proofAggregation = try Data(hex: container.decode(String.self, forKey: .proofAggregation))

        self.init(signatureVerifyKey: signatureVerifyKey, electionVerifyKey: electionVerifyKey, aggregationVerifyKey: aggregationVerifyKey, proofSig: proofSig, proofElection: proofElection, proofAggregation: proofAggregation)
    }
}

public struct ConfigureBakerPayload: Equatable, Serialize, Deserialize, Codable {
    /// The equity capital of the baker
    public let capital: CCD?
    /// Whether the baker's earnings are restaked
    public let restakeEarnings: Bool?
    /// Whether the pool is open for delegators
    public let openForDelegation: OpenStatus?
    /// The key/proof pairs to verify the baker.
    public let keysWithProofs: BakerKeysPayload?
    /// The URL referencing the baker's metadata.
    public let metadataUrl: String? // At most 2048 bytes
    /// The commission the pool owner takes on transaction fees.
    public let transactionFeeCommission: AmountFraction?
    /// The commission the pool owner takes on baking rewards.
    public let bakingRewardCommission: AmountFraction?
    /// The commission the pool owner takes on finalization rewards.
    public let finalizationRewardCommission: AmountFraction?

    public init(capital: CCD? = nil, restakeEarnings: Bool? = nil, openForDelegation: OpenStatus? = nil, keysWithProofs: BakerKeysPayload? = nil, metadataUrl: String? = nil, transactionFeeCommission: AmountFraction? = nil, bakingRewardCommission: AmountFraction? = nil, finalizationRewardCommission: AmountFraction? = nil) {
        self.capital = capital
        self.restakeEarnings = restakeEarnings
        self.openForDelegation = openForDelegation
        self.keysWithProofs = keysWithProofs
        self.metadataUrl = metadataUrl
        self.transactionFeeCommission = transactionFeeCommission
        self.bakingRewardCommission = bakingRewardCommission
        self.finalizationRewardCommission = finalizationRewardCommission
    }

    public static func deserialize(_ data: inout Cursor) -> ConfigureBakerPayload? {
        var capital: CCD?
        var restakeEarnings: Bool?
        var openForDelegation: OpenStatus?
        var keysWithProofs: BakerKeysPayload?
        var metadataUrl: String?
        var transactionFeeCommission: AmountFraction?
        var bakingRewardCommission: AmountFraction?
        var finalizationRewardCommission: AmountFraction?

        guard let bitmap = data.parseUInt(UInt16.self) else { return nil }
        if bitmap & 1 != 0 {
            guard let amount = CCD.deserialize(&data) else { return nil }
            capital = amount
        }
        if bitmap & (1 << 1) != 0 {
            guard let restake = data.parseBool() else { return nil }
            restakeEarnings = restake
        }
        if bitmap & (1 << 2) != 0 {
            guard let openStatus = OpenStatus.deserialize(&data) else { return nil }
            openForDelegation = openStatus
        }
        if bitmap & (1 << 3) != 0 {
            guard let keys = BakerKeysPayload.deserialize(&data) else { return nil }
            keysWithProofs = keys
        }
        if bitmap & (1 << 4) != 0 {
            guard let url = data.readString(prefixLength: UInt16.self) else { return nil }
            metadataUrl = url
        }
        if bitmap & (1 << 5) != 0 {
            guard let commission = AmountFraction.deserialize(&data) else { return nil }
            transactionFeeCommission = commission
        }
        if bitmap & (1 << 6) != 0 {
            guard let commission = AmountFraction.deserialize(&data) else { return nil }
            bakingRewardCommission = commission
        }
        if bitmap & (1 << 7) != 0 {
            guard let commission = AmountFraction.deserialize(&data) else { return nil }
            finalizationRewardCommission = commission
        }

        return .init(capital: capital, restakeEarnings: restakeEarnings, openForDelegation: openForDelegation, keysWithProofs: keysWithProofs, metadataUrl: metadataUrl, transactionFeeCommission: transactionFeeCommission, bakingRewardCommission: bakingRewardCommission, finalizationRewardCommission: finalizationRewardCommission)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        var res = 0

        var bitmap: UInt16 = 0
        func setBit(_ pos: Int, cond: Bool) {
            if cond { bitmap = bitmap | (1 << pos) }
        }

        setBit(0, cond: capital != nil)
        setBit(1, cond: restakeEarnings != nil)
        setBit(2, cond: openForDelegation != nil)
        setBit(3, cond: keysWithProofs != nil)
        setBit(4, cond: metadataUrl != nil)
        setBit(5, cond: transactionFeeCommission != nil)
        setBit(6, cond: bakingRewardCommission != nil)
        setBit(7, cond: finalizationRewardCommission != nil)
        res += buffer.writeInteger(bitmap)

        if let capital = capital {
            res += buffer.writeSerializable(capital)
        }
        if let restakeEarnings = restakeEarnings {
            res += buffer.writeBool(restakeEarnings)
        }
        if let openForDelegation = openForDelegation {
            res += buffer.writeSerializable(openForDelegation)
        }
        if let keysWithProofs = keysWithProofs {
            res += buffer.writeSerializable(keysWithProofs)
        }
        if let metadataUrl = metadataUrl {
            res += buffer.writeString(metadataUrl, prefixLength: UInt16.self)
        }
        if let transactionFeeCommission = transactionFeeCommission {
            res += buffer.writeSerializable(transactionFeeCommission)
        }
        if let bakingRewardCommission = bakingRewardCommission {
            res += buffer.writeSerializable(bakingRewardCommission)
        }
        if let finalizationRewardCommission = finalizationRewardCommission {
            res += buffer.writeSerializable(finalizationRewardCommission)
        }
        return res
    }
}

public struct ConfigureDelegationPayload: Equatable, Serialize, Deserialize, Codable {
    /// The equity capital of the baker
    public let capital: CCD?
    /// Whether the baker's earnings are restaked
    public let restakeEarnings: Bool?
    /// The delegation target to add the stake to
    public let delegationTarget: DelegationTarget?

    public init(capital: CCD? = nil, restakeEarnings: Bool? = nil, delegationTarget: DelegationTarget? = nil) {
        self.capital = capital
        self.restakeEarnings = restakeEarnings
        self.delegationTarget = delegationTarget
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        var res = 0

        var bitmap: UInt16 = 0
        func setBit(_ pos: Int, cond: Bool) {
            if cond { bitmap = bitmap | (1 << pos) }
        }

        setBit(0, cond: capital != nil)
        setBit(1, cond: restakeEarnings != nil)
        setBit(2, cond: delegationTarget != nil)
        res += buffer.writeInteger(bitmap)

        if let capital = capital {
            res += buffer.writeSerializable(capital)
        }
        if let restakeEarnings = restakeEarnings {
            res += buffer.writeBool(restakeEarnings)
        }
        if let delegationTarget = delegationTarget {
            res += buffer.writeSerializable(delegationTarget)
        }

        return res
    }

    public static func deserialize(_ data: inout Cursor) -> ConfigureDelegationPayload? {
        var capital: CCD?
        var restakeEarnings: Bool?
        var delegationTarget: DelegationTarget?

        guard let bitmap = data.parseUInt(UInt16.self) else { return nil }
        if bitmap & 1 == 1 {
            guard let amount = CCD.deserialize(&data) else { return nil }
            capital = amount
        }
        if bitmap & (1 << 1) != 0 {
            guard let restake = data.parseBool() else { return nil }
            restakeEarnings = restake
        }
        if bitmap & (1 << 2) != 0 {
            guard let target = DelegationTarget.deserialize(&data) else { return nil }
            delegationTarget = target
        }

        return .init(capital: capital, restakeEarnings: restakeEarnings, delegationTarget: delegationTarget)
    }
}

/// An error happened while decoding the parameter of a ``AccountTransactionPayload`` into a JSON string
public enum ParameterJsonError: Error {
    /// Transaction type has no parameter
    case invalidTransactionType
    /// Decoding the parameter failed. More information is available on the inner ``SchemaError``
    case decodingFailed(error: SchemaError)
}

/// The payload for an account transaction. Only contains payloads valid from protocol version 7
public enum AccountTransactionPayload: Equatable {
    case deployModule(_ module: WasmModule)
    case initContract(amount: CCD, modRef: ModuleReference, initName: InitName, param: Parameter)
    case updateContract(amount: CCD, address: ContractAddress, receiveName: ReceiveName, message: Parameter)
    case transfer(amount: CCD, receiver: AccountAddress, memo: Memo? = nil)
    case updateCredentialKeys(credId: CredentialRegistrationID, keys: CredentialPublicKeys)
    case transferToPublic(_ data: SecToPubTransferData)
    case transferWithSchedule(receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo? = nil)
    case updateCredentials(newCredInfos: [CredentialIndex: CredentialDeploymentInfo], removeCredIds: [CredentialRegistrationID], newThreshold: UInt8)
    case registerData(_ data: RegisteredData)
    case configureBaker(_ data: ConfigureBakerPayload)
    case configureDelegation(_ data: ConfigureDelegationPayload)
}

public extension AccountTransactionPayload {
    /// Gives a JSON representation of a ``Parameter`` associated with the transaction decoded with the given ``ContractSchema``
    ///
    /// - Parameter schema: The schema to use for decoding the ``Parameter``
    /// - Throws: if this is invoked for any other variant than ``.initContract`` or ``.updateContract``.
    /// - Returns: A JSON string representation of the associated ``Parameter``
    func jsonParameter(schema: ContractSchema) throws -> SchemaJSONString {
        var typeSchema: TypeSchema
        var parameter: Parameter

        switch self {
        case let .initContract(_, _, initName, param):
            parameter = param

            switch schema {
            case let .module(value):
                typeSchema = try value.initParameterSchema(contractName: initName.contractName)
            case let .type(value):
                typeSchema = value
            }
        case let .updateContract(_, _, receiveName, param):
            parameter = param

            switch schema {
            case let .module(value):
                typeSchema = try value.receiveParameterSchema(receiveName: receiveName)
            case let .type(value):
                typeSchema = value
            }
        default:
            throw ParameterJsonError.invalidTransactionType
        }

        return try typeSchema.decode(value: parameter)
    }
}

extension AccountTransactionPayload: Serialize, Deserialize {
    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0

        // Based on 'https://github.com/Concordium/concordium-base/blob/2c3255f39afd73543b5b21bbae1074fb069a0abd/rust-src/concordium_base/src/transactions.rs#L931'.
        switch self {
        case let .deployModule(module):
            res += buffer.writeSerializable(TransactionType.deployModule)
            res += buffer.writeSerializable(module)
        case let .initContract(amount, modRef, initName, param):
            res += buffer.writeSerializable(TransactionType.initContract)
            res += buffer.writeSerializable(amount)
            res += buffer.writeSerializable(modRef)
            res += buffer.writeSerializable(initName)
            res += buffer.writeSerializable(param)
        case let .updateContract(amount, contractAddress, receiveName, param):
            res += buffer.writeSerializable(TransactionType.update)
            res += buffer.writeSerializable(amount)
            res += buffer.writeSerializable(contractAddress)
            res += buffer.writeSerializable(receiveName)
            res += buffer.writeSerializable(param)
        case let .transfer(amount, receiver, memo):
            if let memo {
                res += buffer.writeSerializable(TransactionType.transferWithMemo)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(memo)
                res += buffer.writeSerializable(amount)
            } else {
                res += buffer.writeSerializable(TransactionType.transfer)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(amount)
            }
        case let .updateCredentialKeys(credId, keys):
            res += buffer.writeSerializable(TransactionType.updateCredentialKeys)
            res += buffer.writeSerializable(credId)
            res += buffer.writeSerializable(keys)
        case let .transferToPublic(data):
            res += buffer.writeSerializable(TransactionType.transferToPublic)
            res += buffer.writeSerializable(data)
        case let .transferWithSchedule(receiver, schedule, memo):
            if let memo {
                res += buffer.writeSerializable(TransactionType.transferWithScheduleAndMemo)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(memo)
                res += buffer.writeSerializable(list: schedule, prefixLength: UInt8.self)
            } else {
                res += buffer.writeSerializable(TransactionType.transferWithSchedule)
                res += buffer.writeData(receiver.data)
                res += buffer.writeSerializable(list: schedule, prefixLength: UInt8.self)
            }
        case let .updateCredentials(newCredInfos, removeCredIds, newThreshold):
            res += buffer.writeSerializable(TransactionType.updateCredentials)
            res += buffer.writeSerializable(map: newCredInfos, prefixLength: UInt8.self)
            res += buffer.writeSerializable(list: removeCredIds, prefixLength: UInt8.self)
            res += buffer.writeInteger(newThreshold)
        case let .registerData(data):
            res += buffer.writeSerializable(TransactionType.registerData)
            res += buffer.writeSerializable(data)
        case let .configureBaker(data):
            res += buffer.writeSerializable(TransactionType.configureBaker)
            res += buffer.writeSerializable(data)
        case let .configureDelegation(data):
            res += buffer.writeSerializable(TransactionType.configureDelegation)
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
            guard let amount = CCD.deserialize(&data),
                  let modRef = ModuleReference.deserialize(&data),
                  let initName = InitName.deserialize(&data),
                  let param = Parameter.deserialize(&data) else { return nil }
            return AccountTransactionPayload.initContract(amount: amount, modRef: modRef, initName: initName, param: param)
        case .update:
            guard let amount = CCD.deserialize(&data),
                  let contractAddress = ContractAddress.deserialize(&data),
                  let receiveName = ReceiveName.deserialize(&data),
                  let message = Parameter.deserialize(&data) else { return nil }
            return AccountTransactionPayload.updateContract(amount: amount, address: contractAddress, receiveName: receiveName, message: message)
        case .transfer:
            guard let receiver = AccountAddress.deserialize(&data),
                  let amount = CCD.deserialize(&data) else { return nil }
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
                  let schedule = data.deserialize(listOf: ScheduledTransfer.self, prefixLength: UInt8.self) else { return nil }
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
                  let amount = CCD.deserialize(&data) else { return nil }
            return .transfer(amount: amount, receiver: receiver, memo: memo)
        case .transferWithScheduleAndMemo:
            guard let receiver = AccountAddress.deserialize(&data),
                  let memo = Memo.deserialize(&data),
                  let schedule = data.deserialize(listOf: ScheduledTransfer.self, prefixLength: UInt8.self) else { return nil }
            return .transferWithSchedule(receiver: receiver, schedule: schedule, memo: memo)
        case .configureBaker:
            guard let payload = ConfigureBakerPayload.deserialize(&data) else { return nil }
            return .configureBaker(payload)
        case .configureDelegation:
            guard let payload = ConfigureDelegationPayload.deserialize(&data) else { return nil }
            return .configureDelegation(payload)
        case .addBaker, .removeBaker, .updateBakerStake, .updateBakerRestakeEarnings, .updateBakerKeys:
            return nil // Not supported, invalid since protocol version 4
        case .encryptedAmountTransfer, .encryptedAmountTransferWithMemo, .transferToEncrypted:
            return nil // Not supported, invalid since protocol version 7
        }
    }
}

extension AccountTransactionPayload: FromGRPC, ToGRPC {
    static func fromGRPC(_ gRPC: Concordium_V2_AccountTransactionPayload) throws -> AccountTransactionPayload {
        guard let payload = gRPC.payload else {
            throw GRPCError.missingRequiredValue("Expected a payload value on GRPC type")
        }
        switch payload {
        case let .deployModule(src):
            return try .deployModule(WasmModule.fromGRPC(src))
        case let .transfer(payload):
            return try .transfer(amount: CCD.fromGRPC(payload.amount), receiver: AccountAddress.fromGRPC(payload.receiver))
        case let .transferWithMemo(payload):
            return try .transfer(amount: CCD.fromGRPC(payload.amount), receiver: AccountAddress.fromGRPC(payload.receiver), memo: Memo.fromGRPC(payload.memo))
        case let .initContract(payload):
            return try .initContract(amount: CCD.fromGRPC(payload.amount), modRef: ModuleReference.fromGRPC(payload.moduleRef), initName: InitName.fromGRPC(payload.initName), param: Parameter.fromGRPC(payload.parameter))
        case let .updateContract(payload):
            return try .updateContract(amount: CCD.fromGRPC(payload.amount), address: ContractAddress.fromGRPC(payload.address), receiveName: ReceiveName.fromGRPC(payload.receiveName), message: Parameter.fromGRPC(payload.parameter))
        case let .registerData(data):
            return try .registerData(RegisteredData.fromGRPC(data))
        case let .rawPayload(data):
            return try .deserialize(data) ?! GRPCError.unsupportedValue("Failed to deserialize raw payload")
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
            try accountCredentialDeploymentHash(
                credential: credential,
                expiryUnixSecs: expiry
            )
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
            signatures: signatures
        )
    }

    /// Serializes the account credential deployment
    public func serialize() throws -> SerializedSignedAccountCredentialDeployment {
        let data = try accountCredentialDeploymentSignedPayload(credential: toCryptoType())
        return .init(data: data, expiry: deployment.expiry)
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
