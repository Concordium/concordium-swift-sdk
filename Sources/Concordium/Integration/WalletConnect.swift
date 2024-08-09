import Foundation

struct InitContractJsonBridge: Codable {
    let amount: CCD
    let initName: InitName
    let moduleRef: ModuleReference
    let param: Parameter
    let maxContractExecutionEnergy: Energy
}

struct UpdateContractJsonBridge: Codable {
    let amount: CCD
    let address: ContractAddress
    let receiveName: ReceiveName
    let message: Parameter
    let maxContractExecutionEnergy: Energy
}

struct TransferJsonBridge: Codable {
    let amount: CCD
    let receiver: AccountAddress
    let memo: Memo?
}

struct UpdateCredentialKeysJsonBridge: Codable {
    let credId: CredentialRegistrationID
    let keys: CredentialPublicKeys
}

struct TransferWithScheduleJsonBridge: Codable {
    let receiver: AccountAddress
    let schedule: [ScheduledTransfer]
    let memo: Memo?
}

struct IndexedCredentialDeploymentInfoJsonBridge: Codable {
    let index: CredentialIndex
    let cdi: CredentialDeploymentInfo
}

struct UpdateCredentialsJsonBridge: Codable {
    let newCredentials: [IndexedCredentialDeploymentInfoJsonBridge]
    let removeCredentialIds: [CredentialRegistrationID]
    let threshold: UInt8
    let currentNumberOfCredentials: UInt64
}

struct RegisterDataJsonBridge: Codable {
    let data: RegisteredData

    enum CodingKeys: String, CodingKey {
        case data
    }
}

/// Describes payloads commonly received in a wallet through walletconnect.
/// Only contains variants corresponding to transaction payloads valid from protocol version 7
public enum WalletConnectTransactionPayload: Equatable {
    case deployModule(_ module: WasmModule)
    case initContract(amount: CCD, modRef: ModuleReference, initName: InitName, param: Parameter, maxEnergy: Energy)
    case updateContract(amount: CCD, address: ContractAddress, receiveName: ReceiveName, message: Parameter, maxEnergy: Energy)
    case transfer(amount: CCD, receiver: AccountAddress, memo: Memo? = nil)
    case updateCredentialKeys(credId: CredentialRegistrationID, keys: CredentialPublicKeys)
    case transferToPublic(_ data: SecToPubTransferData)
    case transferWithSchedule(receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo? = nil)
    case updateCredentials(newCredInfos: [CredentialIndex: CredentialDeploymentInfo], removeCredIds: [CredentialRegistrationID], newThreshold: UInt8, numCurrentCredentials: UInt64)
    case registerData(_ data: RegisteredData)
    case configureBaker(_ data: ConfigureBakerPayload)
    case configureDelegation(_ data: ConfigureDelegationPayload)

    // TODO:
    // public func validFor(transactionType: AccountTransactionType) -> Bool
    // public func createTransaction(sender: AccountAddress) -> AccountTransaction
}

public enum WalletConnectSchema: Equatable {
    case parameter(value: String)
    case module(value: String, version: ModuleSchemaVersion?)
}

extension WalletConnectSchema: Decodable {
    private enum SchemaType: String, Codable {
        case parameter
        case module
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case value
        case version
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        let type = try container.decode(SchemaType.self, forKey: Self.CodingKeys.type)
        let value = try container.decode(String.self, forKey: Self.CodingKeys.value)

        switch type {
        case .parameter:
            self = .parameter(value: value)
        case .module:
            let version = try container.decodeIfPresent(ModuleSchemaVersion.self, forKey: Self.CodingKeys.version)
            self = .module(value: value, version: version)
        }
    }
}

/// Describes the different transaction types available
enum TransactionTypeString: String, Codable {
    case deployModule
    case initContract
    case updateContract
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

    var transactionType: TransactionType {
        switch self {
        case .deployModule:
            return .deployModule
        case .initContract:
            return .initContract
        case .updateContract:
            return .updateContract
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

public struct WalletConnectSendTransactionParam: Equatable {
    let type: TransactionType
    let sender: AccountAddress
    let payload: WalletConnectTransactionPayload
    let schema: WalletConnectSchema?

    init(type: TransactionType, sender: AccountAddress, payload: WalletConnectTransactionPayload, schema: WalletConnectSchema? = nil) {
        self.type = type
        self.sender = sender
        self.payload = payload
        self.schema = schema
    }
}

/// This matches the JSON format produced for WalletConnect by the NPM package `@concordium/wallet-connectors`
extension WalletConnectSendTransactionParam: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case sender
        case payload
        case schema
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        type = try container.decode(TransactionTypeString.self, forKey: Self.CodingKeys.type).transactionType
        sender = try container.decode(AccountAddress.self, forKey: Self.CodingKeys.sender)
        schema = try container.decodeIfPresent(WalletConnectSchema.self, forKey: Self.CodingKeys.schema)

        switch type {
        case .deployModule:
            let data = try container.decode(WasmModule.self, forKey: Self.CodingKeys.payload)
            payload = .deployModule(data)
        case .initContract:
            let data = try container.decode(InitContractJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .initContract(amount: data.amount, modRef: data.moduleRef, initName: data.initName, param: data.param, maxEnergy: data.maxContractExecutionEnergy)
        case .updateContract:
            let data = try container.decode(UpdateContractJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .updateContract(amount: data.amount, address: data.address, receiveName: data.receiveName, message: data.message, maxEnergy: data.maxContractExecutionEnergy)
        case .transfer, .transferWithMemo:
            let data = try container.decode(TransferJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .transfer(amount: data.amount, receiver: data.receiver, memo: data.memo)
        case .updateCredentialKeys:
            let data = try container.decode(UpdateCredentialKeysJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .updateCredentialKeys(credId: data.credId, keys: data.keys)
        case .transferToPublic:
            let data = try container.decode(SecToPubTransferData.self, forKey: Self.CodingKeys.payload)
            payload = .transferToPublic(data)
        case .transferWithSchedule, .transferWithScheduleAndMemo:
            let data = try container.decode(TransferWithScheduleJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .transferWithSchedule(receiver: data.receiver, schedule: data.schedule, memo: data.memo)
        case .updateCredentials:
            let data = try container.decode(UpdateCredentialsJsonBridge.self, forKey: Self.CodingKeys.payload)
            let newCredInfos = data.newCredentials.reduce(into: [:]) { map, item in map[item.index] = item.cdi }
            payload = .updateCredentials(newCredInfos: newCredInfos, removeCredIds: data.removeCredentialIds, newThreshold: data.threshold, numCurrentCredentials: data.currentNumberOfCredentials)
        case .registerData:
            let data = try container.decode(RegisterDataJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .registerData(data.data)
        case .configureBaker:
            let data = try container.decode(ConfigureBakerPayload.self, forKey: Self.CodingKeys.payload)
            payload = .configureBaker(data)
        case .configureDelegation:
            let data = try container.decode(ConfigureDelegationPayload.self, forKey: Self.CodingKeys.payload)
            payload = .configureDelegation(data)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Decoding transaction payloads of type \(type) is not supported"))
        }
    }
}

public struct WalletConnectSignMessageParam {}
