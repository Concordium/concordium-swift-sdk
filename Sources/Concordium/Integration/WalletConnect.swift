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

/// Describes parameter supplied to a walletconnect "sign_and_send_transaction" request
/// as produced by the NPM package `@concordium/wallet-connectors`.
///
/// This is not meant to be initialized, but rather decoded from JSON.
public struct WalletConnectSendTransactionParam: Equatable {
    public let type: TransactionType
    public let sender: AccountAddress
    public let payload: WalletConnectTransactionPayload
    public let schema: ContractSchema?

    init(type: TransactionType, sender: AccountAddress, payload: WalletConnectTransactionPayload, schema: ContractSchema? = nil) {
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
        schema = try container.decodeIfPresent(ContractSchema.self, forKey: Self.CodingKeys.schema)

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

/// Describes parameter supplied to a walletconnect "sign_message" request
/// as produced by the NPM package `@concordium/wallet-connectors`
public struct WalletConnectRequestVerifiablePresentationParam: Decodable {
    let challenge: Data
    let credentialStatements: [CredentialStatement]

    public enum CredentialStatement {
        case account(issuers: [UInt32], statement: [AtomicStatementV1])
        case web3id(issuers: [ContractAddress], statement: [AtomicStatementV2])
    }
}

extension WalletConnectRequestVerifiablePresentationParam.CredentialStatement: Decodable {
    private enum TypeValue: String, Codable {
        case sci
        case cred
    }

    private enum NestedKeys: CodingKey {
        case type
        case issuers
    }

    private enum CodingKeys: CodingKey {
        case idQualifier
        case statement
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nested = try container.nestedContainer(keyedBy: NestedKeys.self, forKey: .statement)
        let type = try nested.decode(TypeValue.self, forKey: .type)
        switch type {
        case .sci: 
            let issuers = try nested.decode([UInt32].self, forKey: .issuers)
            let statement = try container.decode([AtomicStatementV1].self, forKey: .statement)
            self = .account(issuers: issuers, statement: statement)
        case .cred: 
            let issuers = try nested.decode([ContractAddress].self, forKey: .issuers)
            let statement = try container.decode([AtomicStatementV2].self, forKey: .statement)
            self = .web3id(issuers: issuers, statement: statement)
        }
    }
}

/// Describes wallet connect requests commonly supported
/// as produced by the NPM package `@concordium/wallet-connectors`
public enum WalletConnectRequest {
    case signMessage(param: WalletConnectSignMessageParam)
    case sendTransaction(param: WalletConnectSendTransactionParam)
    case requestVerifiableCredential(param: WalletConnectRequestVerifiablePresentationParam)
}

extension WalletConnectRequest: Decodable {
    public enum Method: String, Codable {
        case signAndSendTransaction = "sign_and_send_transaction"
        case signMessage = "sign_message"
        case requestVerifiablePresentation = "request_verifiable_presentation"
    }

    private enum CodingKeys: CodingKey {
        case method
        case params
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let method = try container.decode(Method.self, forKey: .method)
        switch method {
        case .signMessage: self = .signMessage(param: try container.decode(WalletConnectSignMessageParam.self, forKey: .params))
        case .signAndSendTransaction: self = .sendTransaction(param: try container.decode(WalletConnectSendTransactionParam.self, forKey: .params))
        case .requestVerifiablePresentation: self = .requestVerifiableCredential(param: try container.decode(WalletConnectRequestVerifiablePresentationParam.self, forKey: .params))
        }
    }
}
