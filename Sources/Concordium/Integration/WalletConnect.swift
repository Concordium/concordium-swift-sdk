import Foundation

/// Describes payloads commonly received in a wallet through walletconnect.
/// Only contains variants corresponding to transaction payloads valid from protocol version 7
public enum WalletConnectPayload: Equatable {
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
}

public enum WalletConnectPayloadError: Error {
    case parse(type: TransactionType)
    case unsupported(type: TransactionType)
}

extension WalletConnectPayload: Encodable { // TODO: this needs manual implementation + unit tests...
    /// Decode the given ``Data`` as JSON corresponding to the given ``TransactionType``
    public init(json: Data, assuming type: TransactionType) throws {
        let jsonDecoder = JSONDecoder()

        do {
            switch type {
            case .deployModule:
                let data = try jsonDecoder.decode(WasmModule.self, from: json)
                self = .deployModule(data)
            case .initContract:
                let payload = try jsonDecoder.decode(InitContractJsonBridge.self, from: json)
                self = .initContract(amount: payload.amount, modRef: payload.moduleRef, initName: payload.initName, param: payload.param, maxEnergy: payload.maxContractExecutionEnergy)
            case .updateContract:
                let payload = try jsonDecoder.decode(UpdateContractJsonBridge.self, from: json)
                self = .updateContract(amount: payload.amount, address: payload.address, receiveName: payload.receiveName, message: payload.message, maxEnergy: payload.maxContractExecutionEnergy)
            case .transfer, .transferWithMemo:
                let payload = try jsonDecoder.decode(TransferJsonBridge.self, from: json)
                self = .transfer(amount: payload.amount, receiver: payload.receiver, memo: payload.memo)
            case .updateCredentialKeys:
                let payload = try jsonDecoder.decode(UpdateCredentialKeysJsonBridge.self, from: json)
                self = .updateCredentialKeys(credId: payload.credId, keys: payload.keys)
            case .transferToPublic:
                let payload = try jsonDecoder.decode(SecToPubTransferData.self, from: json)
                self = .transferToPublic(payload)
            case .transferWithSchedule, .transferWithScheduleAndMemo:
                let payload = try jsonDecoder.decode(TransferWithScheduleJsonBridge.self, from: json)
                self = .transferWithSchedule(receiver: payload.receiver, schedule: payload.schedule, memo: payload.memo)
            case .updateCredentials:
                let payload = try jsonDecoder.decode(UpdateCredentialsJsonBridge.self, from: json)
                let newCredInfos = payload.newCredentials.reduce(into: [:]) { map, item in map[item.index] = item.cdi }
                self = .updateCredentials(newCredInfos: newCredInfos, removeCredIds: payload.removeCredentialIds, newThreshold: payload.threshold, numCurrentCredentials: payload.currentNumberOfCredentials)
            case .registerData:
                let payload = try jsonDecoder.decode(RegisterDataJsonBridge.self, from: json)
                self = .registerData(payload.data)
            case .configureBaker:
                let payload = try jsonDecoder.decode(ConfigureBakerPayload.self, from: json)
                self = .configureBaker(payload)
            case .configureDelegation:
                let payload = try jsonDecoder.decode(ConfigureDelegationPayload.self, from: json)
                self = .configureDelegation(payload)
            default:
                throw WalletConnectPayloadError.unsupported(type: type)
            }
        } catch is DecodingError {
            throw WalletConnectPayloadError.parse(type: type)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case let .deployModule(data):
            try data.encode(to: encoder)
        case let .initContract(amount, modRef, initName, param, maxEnergy):
            let bridge = InitContractJsonBridge(amount: amount, initName: initName, moduleRef: modRef, param: param, maxContractExecutionEnergy: maxEnergy)
            try bridge.encode(to: encoder)
        case let .updateContract(amount, address, receiveName, message, maxEnergy):
            let bridge = UpdateContractJsonBridge(amount: amount, address: address, receiveName: receiveName, message: message, maxContractExecutionEnergy: maxEnergy)
            try bridge.encode(to: encoder)
        default: // TODO: remove this when exhausted
            throw EncodingError.invalidValue(String.self, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode type yet..."))
        }
    }
}
