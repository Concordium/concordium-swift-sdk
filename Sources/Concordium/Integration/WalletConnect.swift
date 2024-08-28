import Foundation

struct DeployModuleJsonBridge {
    /// If `nil`, it is assumed that `source` has version and length embedded
    let version: WasmVersion?
    let source: Data
}

extension DeployModuleJsonBridge: Decodable {
    private enum CodingKeys: String, CodingKey {
        case version
        case source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        version = try container.decodeIfPresent(WasmVersion.self, forKey: .version)
        source = try Data(hex: container.decode(String.self, forKey: .source))
    }
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
    let toAddress: AccountAddress
    let memo: Memo?
}

struct UpdateCredentialKeysJsonBridge: Codable {
    let credId: CredentialRegistrationID
    let keys: CredentialPublicKeys
}

struct TransferWithScheduleJsonBridge: Codable {
    let toAddress: AccountAddress
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

/// Describes payloads received in a wallet through walletconnect.
/// Only contains relevant variants corresponding to transaction payloads valid from protocol version 7
public enum WalletConnectTransactionPayload: Equatable {
    case deployModule(version: WasmVersion?, source: Data)
    case initContract(amount: CCD, modRef: ModuleReference, initName: InitName, param: Parameter, maxEnergy: Energy)
    case updateContract(amount: CCD, address: ContractAddress, receiveName: ReceiveName, message: Parameter, maxEnergy: Energy)
    case transfer(amount: CCD, receiver: AccountAddress, memo: Memo? = nil)
    case transferWithSchedule(receiver: AccountAddress, schedule: [ScheduledTransfer], memo: Memo? = nil)
    case registerData(_ data: RegisteredData)
}

/// Represents a schema to be used for decoding the received parameter for either update/init contract transaction requests.
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

/// Describes parameter supplied to a walletconnect "sign_and_send_transaction" request
/// as produced by the NPM package `@concordium/wallet-connectors`.
///
/// This is not meant to be initialized, but rather decoded from JSON.
public struct WalletConnectSendTransactionParam: Equatable {
    public let type: TransactionType
    public let sender: AccountAddress
    public let payload: WalletConnectTransactionPayload
    public let schema: WalletConnectSchema?

    init(type: TransactionType, sender: AccountAddress, payload: WalletConnectTransactionPayload, schema: WalletConnectSchema? = nil) {
        self.type = type
        self.sender = sender
        self.payload = payload
        self.schema = schema
    }

    /// Convert the ``WalletConnectSendTransactionParam`` into a signable transaction.
    ///
    /// ```swift
    /// let param = try JSONDecorder().decode(WalletConnectSendTransactionParam.self)
    /// let transaction = param.createTransaction()
    /// ```
    ///
    /// - Throws: ``DeserializeError`` in case a malformed ``WasmModule`` is deserialized due to missing version/length information.
    ///   This only happens if the version was not present in the decoded JSON
    public func createTransaction() throws -> AccountTransaction {
        switch payload {
        case .deployModule(version: nil, let source):
            // If `version` is not included, assume source is already a ``WasmModule`` serialized according to ``Serialize``
            let wasmModule = try WasmModule.deserialize(source) ?! DeserializeError(WasmModule.self, data: source)
            return .deployModule(sender: sender, module: wasmModule)
        case let .deployModule(version?, source):
            return .deployModule(sender: sender, module: WasmModule(version: version, source: source))
        case let .initContract(amount, modRef, initName, param, maxEnergy):
            return .initContract(sender: sender, amount: amount, modRef: modRef, initName: initName, param: param, maxEnergy: maxEnergy)
        case let .updateContract(amount, address, receiveName, message, maxEnergy):
            return .updateContract(sender: sender, amount: amount, contractAddress: address, receiveName: receiveName, param: message, maxEnergy: maxEnergy)
        case let .registerData(data):
            return .registerData(sender: sender, data: data)
        case let .transfer(amount, receiver, memo):
            return .transfer(sender: sender, receiver: receiver, amount: amount, memo: memo)
        case let .transferWithSchedule(receiver, schedule, memo):
            return .transferWithSchedule(sender: sender, receiver: receiver, schedule: schedule, memo: memo)
        }
    }
}

extension WalletConnectSendTransactionParam: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case sender
        case payload
        case schema
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        type = try container.decode(TransactionType.self, forKey: Self.CodingKeys.type)
        sender = try container.decode(AccountAddress.self, forKey: Self.CodingKeys.sender)
        schema = try container.decodeIfPresent(WalletConnectSchema.self, forKey: Self.CodingKeys.schema)

        switch type {
        case .deployModule:
            let data = try container.decode(DeployModuleJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .deployModule(version: data.version, source: data.source)
        case .initContract:
            let data = try container.decode(InitContractJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .initContract(amount: data.amount, modRef: data.moduleRef, initName: data.initName, param: data.param, maxEnergy: data.maxContractExecutionEnergy)
        case .update:
            let data = try container.decode(UpdateContractJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .updateContract(amount: data.amount, address: data.address, receiveName: data.receiveName, message: data.message, maxEnergy: data.maxContractExecutionEnergy)
        case .transfer, .transferWithMemo:
            let data = try container.decode(TransferJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .transfer(amount: data.amount, receiver: data.toAddress, memo: data.memo)
        case .transferWithSchedule, .transferWithScheduleAndMemo:
            let data = try container.decode(TransferWithScheduleJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .transferWithSchedule(receiver: data.toAddress, schedule: data.schedule, memo: data.memo)
        case .registerData:
            let data = try container.decode(RegisterDataJsonBridge.self, forKey: Self.CodingKeys.payload)
            payload = .registerData(data.data)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Decoding transaction payloads of type \(type) is not supported"))
        }
    }
}

/// Describes parameter supplied to a walletconnect "sign_message" request
/// as produced by the NPM package `@concordium/wallet-connectors`
public enum WalletConnectSignMessageParam {
    case string(message: String)
    case binary(message: Data, schema: Data)
}

extension WalletConnectSignMessageParam: Decodable {
    private enum CodingKeys: String, CodingKey {
        case message
        case schema
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        let message = try container.decode(String.self, forKey: .message)
        let schema = try container.decodeIfPresent(String.self, forKey: .schema).map { try Data(hex: $0) }

        if let schema = schema {
            let binaryMessage = try Data(hex: message) ?! DecodingError.dataCorruptedError(forKey: Self.CodingKeys.message, in: container, debugDescription: "Expected message to be a hex string")
            self = .binary(message: binaryMessage, schema: schema)
        } else {
            self = .string(message: message)
        }
    }
}
