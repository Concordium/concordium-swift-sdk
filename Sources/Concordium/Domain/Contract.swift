import ConcordiumWalletCrypto
import Foundation
import NIO

/// The max size of a `Parameter`
let PARAMETER_SIZE_MAX: UInt16 = 65535
/// The max length of a contract receive name
let FUNC_NAME_MAX: UInt8 = 100

/// Error thrown when decoding/encoding data using ``ContractSchema``
public typealias SchemaError = ConcordiumWalletCrypto.SchemaError

/// Represents a schema for a single type in a smart contract, i.e. one of:
/// - ``Parameter``
/// - ``ReturnValue``
/// - ``ContractError``
/// - ``ContractEvent``
public typealias TypeSchema = ConcordiumWalletCrypto.TypeSchema

/// Represents a schema of a specific version for a smart contract module.
public typealias ModuleSchema = ConcordiumWalletCrypto.ModuleSchema

/// Represents JSON strings returned when decoding data using contract schemas
public struct SchemaJSONString: CustomStringConvertible {
    /// The inner JSON string value
    public let value: String
    public var description: String { value }

    init(_ value: String) {
        self.value = value
    }

    /// Parse the JSON string into the ``Decodable`` type given as input
    public func parse<T: Decodable>(_: T.Type) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: value.data(using: .utf8)!)
    }
}

func base64RemovePadding(value: String) -> String {
    value.trimmingCharacters(in: .init(charactersIn: "="))
}

func base64AddPadding(value: String) -> String {
    if value.count % 4 == 0 {
        return value
    }
    return value + String(repeating: "=", count: value.count % 4)
}

public extension TypeSchema {
    /// Init from base64 encoded string
    init(base64: String) throws {
        let padded = base64AddPadding(value: base64)
        try self.init(value: Data(base64Encoded: padded) ?! SchemaError.ParseSchema(message: "Failed to construct schema from string value. Base64 string expected."))
    }

    /// Decode the ``Data`` into it's JSON representation
    func decode(data: Data) throws -> SchemaJSONString {
        try SchemaJSONString(deserializeTypeValue(value: data, schema: self))
    }

    /// Decode the ``SchemaCodable`` type into it's JSON representation
    func decode(value: any SchemaCodable) throws -> SchemaJSONString {
        try decode(data: value.value)
    }

    /// Encode the JSON string into ``Data``
    func encode(json: String) throws -> Data {
        try serializeTypeValue(json: json, schema: self)
    }

    /// Encode the JSON string into the ``SchemaCodable`` type specified
    func encode<T: SchemaCodable>(json: String, as _: T.Type) throws -> T {
        try T(encode(json: json))
    }

    /// Encode the ``Encodable`` type specified
    func encode<E: Encodable>(value: E) throws -> Data {
        let encoder = JSONEncoder()
        let json = try String(data: encoder.encode(value), encoding: .utf8)!
        return try encode(json: json)
    }

    /// Encode the ``Encodable`` type specified as the ``SchemaCodable`` type specified
    func encode<E: Encodable, T: SchemaCodable>(value: E, as _: T.Type) throws -> T {
        try T(encode(value: value))
    }

    /// The base64 representation of the schema
    var base64: String {
        base64RemovePadding(value: value.base64EncodedString())
    }

    /// Display the template of the type schema. This is useful when figuring out how to represent the associated type in JSON format.
    var template: String { get throws {
        try displayTypeSchemaTemplate(schema: self)
    }}
}

public extension ModuleSchema {
    /// Init from base64 encoded string
    init(base64: String, version: ModuleSchemaVersion? = nil) throws {
        let padded = base64AddPadding(value: base64)
        let val = try Data(base64Encoded: padded) ?! SchemaError.ParseSchema(message: "Failed to construct schema from string value. Base64 string expected.")
        self.init(value: val, version: version)
    }

    /// Gets the init parameter schema of the contract
    func initParameterSchema(contractName: ContractName) throws -> TypeSchema {
        try getInitParameterSchema(schema: self, contractName: contractName.value)
    }

    /// Gets the init error schema of the contract
    func initErrorSchema(contractName: ContractName) throws -> TypeSchema {
        try getInitErrorSchema(schema: self, contractName: contractName.value)
    }

    /// Gets the parameter schema of the contract for the specified entrypoint
    func receiveParameterSchema(receiveName: ReceiveName) throws -> TypeSchema {
        try getReceiveParameterSchema(schema: self, contractName: receiveName.contractName.value, functionName: receiveName.entrypointName.value)
    }

    /// Gets the return value schema of the contract for the specified entrypoint
    func receiveReturnValueSchema(receiveName: ReceiveName) throws -> TypeSchema {
        try getReceiveReturnValueSchema(schema: self, contractName: receiveName.contractName.value, functionName: receiveName.entrypointName.value)
    }

    /// Gets the Error schema of the contract for the specified entrypoint
    func receiveErrorSchema(receiveName: ReceiveName) throws -> TypeSchema {
        try getReceiveErrorSchema(schema: self, contractName: receiveName.contractName.value, functionName: receiveName.entrypointName.value)
    }

    /// Gets schema for events emitted by the contract
    func eventSchema(contractName: ContractName) throws -> TypeSchema {
        try getEventSchema(schema: self, contractName: contractName.value)
    }

    /// The base64 representation of the schema
    var base64: String {
        base64RemovePadding(value: value.base64EncodedString())
    }
}

/// Describes types which wrap data that can be decoded with contract schemas
public protocol SchemaCodable {
    /// The inner value of the schema-codable type
    var value: Data { get }
    init(_ value: Data) throws
}

public extension SchemaCodable {
    /// Decode the value according to the supplied ``TypeSchema``
    func decode(schema: TypeSchema) throws -> SchemaJSONString {
        try schema.decode(value: self)
    }

    /// Initialize from a JSON string and a corresponding ``TypeSchema``
    init(json: String, schema: TypeSchema) throws {
        self = try schema.encode(json: json, as: Self.self)
    }

    /// Initialize from a ``Codable`` and a corresponding ``TypeSchema``
    init(json: any Codable, schema: TypeSchema) throws {
        self = try schema.encode(json: String(data: JSONEncoder().encode(json), encoding: .utf8)!, as: Self.self)
    }
}

/// Describes the different versions of contract module schemas.
public typealias ModuleSchemaVersion = ConcordiumWalletCrypto.ModuleSchemaVersion

extension ModuleSchemaVersion: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(UInt8.self)

        switch value {
        case 0:
            self = .v0
        case 1:
            self = .v1
        case 2:
            self = .v2
        case 3:
            self = .v3
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value \(value) is out of bounds for type ModuleSchemaVersion")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .v0:
            try container.encode(UInt8(0))
        case .v1:
            try container.encode(UInt8(1))
        case .v2:
            try container.encode(UInt8(2))
        case .v3:
            try container.encode(UInt8(3))
        }
    }
}

/// Represents a schema to be used for encoding/decoding smart contract types to/from it's corresponding JSON format.
public enum ContractSchema: Equatable {
    /// A schema for a specific type in a smart contract
    case type(_ value: TypeSchema)
    /// A schema for an entire smart contract module
    case module(_ value: ModuleSchema)
}

extension ContractSchema: Decodable {
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
        let value = try Data(base64Encoded: container.decode(String.self, forKey: Self.CodingKeys.value)) ?! DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected base64 encoded string"))

        switch type {
        case .parameter:
            self = .type(TypeSchema(value: value))
        case .module:
            let version = try container.decodeIfPresent(ModuleSchemaVersion.self, forKey: Self.CodingKeys.version)
            self = .module(ModuleSchema(value: value, version: version))
        }
    }
}

/// Wrapper around ``Data`` supplied to a contract init/receive function
public struct Parameter: Equatable, Serialize, Deserialize, FromGRPC, ToGRPC, SchemaCodable {
    typealias GRPC = Concordium_V2_Parameter
    public let value: Data

    public init(unchecked value: Data) {
        self.value = value
    }

    /// Initializes a `Parameter` while checking the data
    /// - Throws: ``DataSizeError`` if passed value exceeds the allowed parameter size
    public init(_ value: Data) throws {
        guard value.count <= PARAMETER_SIZE_MAX else {
            throw DataSizeError(actual: UInt(value.count), max: UInt(PARAMETER_SIZE_MAX))
        }
        self.init(unchecked: value)
    }

    /// Initialize from a type which conforms to ``Serialize``
    public init(serializable: any Serialize) throws {
        try self.init(serializable.serialize())
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(UInt16(value.count)) + buffer.writeData(value)
    }

    public static func deserialize(_ data: inout Cursor) -> Parameter? {
        guard let value = data.read(prefixLength: UInt16.self) else { return nil }
        return try? self.init(value)
    }

    func toGRPC() -> GRPC {
        var g = GRPC()
        g.value = value
        return g
    }

    static func fromGRPC(_ gRPC: GRPC) throws -> Self {
        try Self(gRPC.value)
    }

    /// Decode parameter as the init parameter for a contract specified by it's name
    public func decodeInit(contractName: ContractName, schema: ModuleSchema) throws -> SchemaJSONString {
        let schema = try schema.initParameterSchema(contractName: contractName)
        return try decode(schema: schema)
    }

    /// Init from from a JSON string for a parameter meant for a contract init function
    /// - Parameters:
    ///   - json: the JSON string
    ///   - contractName: the name of the contract to inititalize with the parameter
    ///   - schema: the module schema of the contract module
    public init(json: String, contractName: ContractName, schema: ModuleSchema) throws {
        let schema = try schema.initParameterSchema(contractName: contractName)
        self = try .init(json: json, schema: schema)
    }

    /// Decode parameter as a receive parameter for a contract entrypoint specified by a ``ReceiveName``
    public func decode(receiveName: ReceiveName, schema: ModuleSchema) throws -> SchemaJSONString {
        let schema = try schema.receiveParameterSchema(receiveName: receiveName)
        return try decode(schema: schema)
    }

    /// Init from from a JSON string for a parameter meant for a specific entrypoint.
    /// - Parameters:
    ///   - json: the JSON string
    ///   - receiveName: the receive name of the contract
    ///   - schema: the module schema of the contract module
    public init(json: String, receiveName: ReceiveName, schema: ModuleSchema) throws {
        let schema = try schema.receiveParameterSchema(receiveName: receiveName)
        self = try .init(json: json, schema: schema)
    }
}

extension Parameter: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension Parameter: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

/// Wrapper around ``Data`` returned from contract invocation
public struct ReturnValue: Equatable, SchemaCodable {
    typealias GRPC = Concordium_V2_Parameter
    public let value: Data

    public init(_ value: Data) {
        self.value = value
    }

    public func decode(receiveName: ReceiveName, schema: ModuleSchema) throws -> SchemaJSONString {
        let schema = try schema.receiveReturnValueSchema(receiveName: receiveName)
        return try decode(schema: schema)
    }

    /// Deserialize into the given type
    public func deserialize<D: Deserialize>(_: D.Type) throws -> D {
        try D.deserialize(value)
    }
}

extension ReturnValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension ReturnValue: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

/// Wrapper around ``Data`` returned from contract invocation
public struct ContractError: Equatable, SchemaCodable {
    typealias GRPC = Concordium_V2_Parameter
    public let value: Data

    public init(_ value: Data) {
        self.value = value
    }

    public func decode(receiveName: ReceiveName, schema: ModuleSchema) throws -> SchemaJSONString {
        let schema = try schema.receiveErrorSchema(receiveName: receiveName)
        return try decode(schema: schema)
    }

    /// Deserialize into the given type
    public func deserialize<D: Deserialize>(_: D.Type) throws -> D {
        try D.deserialize(value)
    }
}

extension ContractError: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension ContractError: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

/// Wrapper around serialized contract event
public struct ContractEvent: SchemaCodable {
    public let value: Data

    public init(_ value: Data) {
        self.value = value
    }

    /// Deserialize into the given type
    public func deserialize<D: Deserialize>(_: D.Type) throws -> D {
        try D.deserialize(value)
    }
}

extension ContractEvent: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension ContractEvent: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

extension ContractEvent: FromGRPC {
    typealias GRPC = Concordium_V2_ContractEvent

    static func fromGRPC(_ g: GRPC) throws -> ContractEvent {
        Self(g.value)
    }
}

/// Represents an error happening while checking invariants of some string associated with any contract name
public struct ContractNameError: Error {
    /// A message describing the error
    let message: String
}

/// A wrapper around a contract init name, i.e. with the expected format `init_<contract-name>`
public struct InitName: Serialize, Deserialize, Equatable, FromGRPC, ToGRPC, Hashable {
    typealias GRPC = Concordium_V2_InitName
    public let value: String

    public init(unchecked value: String) {
        self.value = value
    }

    /// Initializes with the value, while checking the associated invariants
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public init(_ value: String) throws {
        guard value.count <= FUNC_NAME_MAX else { throw ContractNameError(message: "InitNames must be at most \(FUNC_NAME_MAX) characters long") }
        guard value.hasPrefix("init_") else { throw ContractNameError(message: "InitNames must be prefixed with 'init_'") }
        guard !value.contains(".") else { throw ContractNameError(message: "InitNames must not contain a '.' character") }
        guard value.allSatisfy(\.isASCII) else { throw ContractNameError(message: "InitNames must consist of only ASCII characters") }

        self.init(unchecked: value)
    }

    /// Initializes from the ``ContractName``
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public init(fromContractName contractName: ContractName) throws {
        try self.init("init_".appending(contractName.value))
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeString(value, prefixLength: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(prefixLength: UInt16.self) else { return nil }
        return try? Self(parsed)
    }

    func toGRPC() -> GRPC {
        var g = GRPC()
        g.value = value
        return g
    }

    static func fromGRPC(_ gRPC: GRPC) throws -> Self {
        try Self(gRPC.value)
    }

    public var contractName: ContractName {
        var index = value.firstIndex(of: "_")! // We know this type always has this in the `init_` prefix
        index = value.index(after: index)
        return ContractName(unchecked: String(value[index...]))
    }
}

extension InitName: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension InitName: CustomStringConvertible {
    public var description: String {
        value
    }
}

/// A wrapper around a contract name, corresponding to the prefix of receive functions.
public struct ContractName: Serialize, Deserialize, Equatable, Hashable {
    public let value: String

    public init(unchecked value: String) {
        self.value = value
    }

    /// Initializes with the value, while checking the associated invariants
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public init(_ value: String) throws {
        guard value.count <= (FUNC_NAME_MAX - 5) else { throw ContractNameError(message: "ContractNames must be at most \(FUNC_NAME_MAX - 5) characters long") }
        guard !value.contains(".") else { throw ContractNameError(message: "ContractNames must not contain a '.' character") }
        guard value.allSatisfy(\.isASCII) else { throw ContractNameError(message: "ContractNames must consist of only ASCII characters") }

        self.init(unchecked: value)
    }

    /// Converts the contract name to a corresponding ``InitName``
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public func initName() throws -> InitName {
        try InitName(fromContractName: self)
    }

    /// Converts the contract name to a corresponding ``ReceiveName``
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public func receiveName(forEntrypoint ep: EntrypointName) throws -> ReceiveName {
        try ReceiveName(contractName: self, entrypoint: ep)
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeString(value, prefixLength: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(prefixLength: UInt16.self) else { return nil }
        return try? Self(parsed)
    }
}

extension ContractName: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension ContractName: CustomStringConvertible {
    public var description: String {
        value
    }
}

/// A wrapper around a contract entrypoint name, corresponding to the receive function in the contract without the contract name prefix
public struct EntrypointName: Serialize, Deserialize, Equatable, Hashable {
    public let value: String

    public init(unchecked value: String) {
        self.value = value
    }

    /// Initializes with the value, while checking the associated invariants
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public init(_ value: String) throws {
        guard value.count <= (FUNC_NAME_MAX - 1) else { throw ContractNameError(message: "EntrypointNames must be at most \(FUNC_NAME_MAX - 1) characters long") }
        guard value.allSatisfy(\.isASCII) else { throw ContractNameError(message: "EntrypointNames must consist of only ASCII characters") }

        self.init(unchecked: value)
    }

    /// Converts the entrypoint name to a corresponding ``ReceiveName``
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public func receiveName(forContractName contractName: ContractName) throws -> ReceiveName {
        try ReceiveName(contractName: contractName, entrypoint: self)
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeString(value, prefixLength: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(prefixLength: UInt16.self) else { return nil }
        return try? Self(parsed)
    }
}

extension EntrypointName: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension EntrypointName: CustomStringConvertible {
    public var description: String {
        value
    }
}

/// A wrapper around a receive name, consisting of a ``ContractName`` and an ``EntrypointName`` in
/// the format `<contract-name>.<entrypoint-name>`
public struct ReceiveName: Serialize, Deserialize, Equatable, FromGRPC, ToGRPC, Hashable {
    typealias GRPC = Concordium_V2_ReceiveName
    public let value: String

    public init(unchecked value: String) {
        self.value = value
    }

    /// Initializes with the value, while checking the associated invariants
    public init(_ value: String) throws {
        guard value.count <= FUNC_NAME_MAX else { throw ContractNameError(message: "ReceiveNames must be at most \(FUNC_NAME_MAX) characters long") }
        guard value.contains(".") else { throw ContractNameError(message: "ReceiveNames must not contain a '.' character") }
        guard value.allSatisfy(\.isASCII) else { throw ContractNameError(message: "ReceiveNames must consist of only ASCII characters") }

        self.init(unchecked: value)
    }

    /// Initializes with the value, while checking the associated invariants
    /// - Throws: ``ContractNameError`` if passed value is invalid
    public init(contractName: ContractName, entrypoint: EntrypointName) throws {
        try self.init(contractName.value.appending(".\(entrypoint.value)"))
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeString(value, prefixLength: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(prefixLength: UInt16.self) else { return nil }
        return try? Self(parsed)
    }

    func toGRPC() -> GRPC {
        var g = GRPC()
        g.value = value
        return g
    }

    static func fromGRPC(_ gRPC: GRPC) throws -> Self {
        try Self(gRPC.value)
    }

    public var contractName: ContractName {
        let index = value.firstIndex(of: ".")! // We know this type always has this as a separator between contract name and entrypoint name
        return ContractName(unchecked: String(value[..<index]))
    }

    public var entrypointName: EntrypointName {
        var index = value.firstIndex(of: ".")! // We know this type always has this as a separator between contract name and entrypoint name
        index = value.index(after: index)
        return EntrypointName(unchecked: String(value[index...]))
    }
}

extension ReceiveName: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

extension ReceiveName: CustomStringConvertible {
    public var description: String {
        value
    }
}

/// Represent a contract update not yet sent to a node.
public struct ContractUpdateProposal {
    /// The CCD amount to supply to the update (if payable, otherwise 0)
    public let amount: CCD
    /// the contract address of the update
    public let address: ContractAddress
    /// the receive name of the update
    public let receiveName: ReceiveName
    /// The serialized parameter
    public let parameter: Parameter
    /// The node client used to send the transaction
    public var client: NodeClient
    /// The energy to supply to the transaction
    public var energy: Energy
}

public extension ContractUpdateProposal {
    /// Add extra energy to the transaction
    mutating func addEnergy(_ energy: Energy) {
        self.energy += energy
    }

    /// Send the proposal to the node
    /// - Parameters:
    ///   - sender: the sender account
    ///   - signer: the signer for the transaction. This should match the keys for the sender account
    ///   - expiry: An optional expiry. Defaults to 5 minutes in the future.
    /// - Throws: If the client fails to submit the transaction
    /// - Returns: A submitted transaction
    func send(sender: AccountAddress, signer: any Signer, expiry: Date = Date(timeIntervalSinceNow: 5 * 60)) async throws -> SubmittedTransaction {
        let nonce = try await client.nextAccountSequenceNumber(address: sender)
        let transaction = AccountTransaction.updateContract(sender: sender, amount: amount, contractAddress: address, receiveName: receiveName, param: parameter, maxEnergy: energy)
        return try await client.send(transaction: signer.sign(transaction: transaction, sequenceNumber: nonce.sequenceNumber, expiry: UInt64(expiry.timeIntervalSince1970)))
    }
}

/// Protocol for interacting with arbitrary smart contracts.
/// - Example
///   ```
///   public struct SomeContract: CotractClient { // now you have a contract client.
///     public let name: ContractName
///     public let address: ContractAddress
///     public let client: NodeClient
///   }
///   let client = GRPCNodeClient(...)
///   let contract = SomeContract(name: ContractName("test"), address: ContractAddress(index: 3, subindex: 0), client: client)
///   ```
public protocol ContractClient {
    /// The name of the contract
    var name: ContractName { get }
    /// The contract address used to query
    var address: ContractAddress { get }
    /// The node client used to query the contract at `address`
    var client: NodeClient { get }
    /// Initialize the contract client
    /// - Parameters:
    ///   - client: the node client to use
    ///   - name: the contract name
    ///   - address: the contract address
    init(client: any NodeClient, name: ContractName, address: ContractAddress)
}

/// Describes errors happening while invoking contract client methods.
public enum ContractClientError: Error {
    /// The return value could not be deserialized.
    case noReturnValue
}

public extension ContractClient {
    /// Initialize the contract client
    /// - Parameters:
    ///   - client: the node client to use
    ///   - address: the contract address
    init(client: NodeClient, address: ContractAddress) async throws {
        let info = try await client.info(contractAddress: address, block: .lastFinal)
        self = .init(client: client, name: info.name, address: address)
    }

    /// Invoke a contract view entrypoint
    /// - Parameters:
    ///   - entrypoint: the entrypoint to invoke
    ///   - param: the parameter for the query to invoke the entrypoint with
    ///   - block: the block to invoke the entrypoint at. Defaults to `.lastFinal`
    /// - Throws: If the query cannot be serialized, if node client request fails, or if the response is nil or cannot be deserialized.
    func view(entrypoint: EntrypointName, param: Parameter, block: BlockIdentifier = .lastFinal) async throws -> ReturnValue {
        var request = try ContractInvokeRequest(contract: address, method: ReceiveName(contractName: name, entrypoint: entrypoint))
        request.parameter = param
        let res = try await client.invokeInstance(request: request, block: block).success()
        guard let response = res.returnValue else { throw ContractClientError.noReturnValue }
        return ReturnValue(response)
    }

    /// Construct a ``ContractUpdateProposal`` by invoking the contract entrypoint. The proposal can then subsequently be signed and submitted to the node.
    /// - Parameters:
    ///   - entrypoint: the entrypoint to invoke
    ///   - param: the parameter for the query to invoke the entrypoint with
    ///   - amount: An optional ``CCD`` amount to add to the query, if it is payable. Defaults to 0 CCD.
    /// - Throws: If the query cannot be serialized, if node client request fails.
    /// - Returns: A corresponding ``ContractUpdateProposal`` which can be signed and submitted.
    func proposal(entrypoint: EntrypointName, param: Parameter, amount: CCD = CCD(microCCD: 0)) async throws -> ContractUpdateProposal {
        var request = try ContractInvokeRequest(contract: address, method: ReceiveName(contractName: name, entrypoint: entrypoint))
        request.parameter = param
        let res = try await client.invokeInstance(request: request, block: .lastFinal).success()
        return ContractUpdateProposal(amount: amount, address: address, receiveName: request.method, parameter: request.parameter, client: client, energy: res.usedEnergy)
    }
}

/// Represents generic contracts, exposing the default interface of ``ContractClient``
public class GenericContract: ContractClient {
    public var name: ContractName
    public var address: ContractAddress
    public var client: any NodeClient

    public required init(client: any NodeClient, name: ContractName, address: ContractAddress) {
        self.client = client
        self.name = name
        self.address = address
    }
}
