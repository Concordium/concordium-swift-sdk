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
    case updateCredentials(newCredInfos: [CredentialIndex: CredentialDeploymentInfo], removeCredIds: [CredentialRegistrationID], newThreshold: UInt8)
    case registerData(_ data: RegisteredData)
    case configureBaker(_ data: ConfigureBakerPayload)
    case configureDelegation(_ data: ConfigureDelegationPayload)
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

extension WalletConnectPayload: Codable { // TODO: this needs manual implementation + unit tests...
    public init(from decoder: any Decoder) throws {
        if let data = try? WasmModule(from: decoder) {
            self = .deployModule(data)
        } else if let payload = try? InitContractJsonBridge.init(from: decoder) {
            self = .initContract(amount: payload.amount, modRef: payload.moduleRef, initName: payload.initName, param: payload.param, maxEnergy: payload.maxContractExecutionEnergy)
        } else if let payload = try? UpdateContractJsonBridge.init(from: decoder) {
            self = .updateContract(amount: payload.amount, address: payload.address, receiveName: payload.receiveName, message: payload.message, maxEnergy: payload.maxContractExecutionEnergy)
        } else {
            throw DecodingError.typeMismatch(WalletConnectPayload.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not decode account transaction payload from value"))
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
            throw EncodingError.invalidValue(String.self, EncodingError.Context.init(codingPath: encoder.codingPath, debugDescription: "Cannot encode type yet..."))
        }
    }
}