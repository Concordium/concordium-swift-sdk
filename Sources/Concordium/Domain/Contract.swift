import Foundation
import NIO

/// The max size of a `Parameter`
let PARAMETER_SIZE_MAX: UInt16 = 65535
/// The max length of a contract receive name
let FUNC_NAME_MAX: UInt8 = 100

/// Error thrown when decoding/encoding data using ``ContractSchema``
public struct SchemaError: Error {
    public let message: String
}

/// Represents a schema for a single type in a smart contract, i.e. one of:
/// - ``Parameter``
/// - ``ReturnValue``
/// - ``ContractError``
/// - ``ContractEvent``
public struct TypeSchema: Equatable {
    public let value: Data
}

public extension TypeSchema {
    func decode(data: Data) throws -> String {
        "" // FIXME: implementation missing
    }

    func decode(value: any SchemaCodable) throws -> String {
        try self.decode(data: value.value)
    }

    func encode(json: String) throws -> Data {
        Data() // FIXME: implementation missing
    }

    func encode<T: SchemaCodable>(json: String, as _: T.Type) throws -> T {
        try T(encode(json: json))
    }
}

public struct ModuleSchema: Equatable {
    public let value: Data
    public let version: ModuleSchemaVersion?
}

public extension ModuleSchema {
    func initParameterSchema(contractName: ContractName) throws -> TypeSchema {
        TypeSchema(value: Data()) // FIXME: implementation..
    }

    func initErrorSchema(contractName: ContractName) throws -> TypeSchema {
        TypeSchema(value: Data()) // FIXME: implementation..
    }

    func updateParameterSchema(receiveName: ReceiveName) throws -> TypeSchema {
        TypeSchema(value: Data()) // FIXME: implementation..
    }

    func updateReturnValueSchema(receiveName: ReceiveName) throws -> TypeSchema {
        TypeSchema(value: Data()) // FIXME: implementation..
    }

    func updateErrorSchema(receiveName: ReceiveName) throws -> TypeSchema {
        TypeSchema(value: Data()) // FIXME: implementation..
    }
}

public protocol SchemaCodable {
    /// The inner value of the schema-codable type
    var value: Data { get }
    init(_ value: Data) throws
}

public extension SchemaCodable {
    func decode(schema: TypeSchema) throws -> String {
        try schema.decode(value: self)
    }

    init(json: String, schema: TypeSchema) throws {
        self = try schema.encode(json: json, as: Self.self)
    }
}

public enum ModuleSchemaVersion: UInt8, Codable {
    case V0
    case V1
    case V2
}

/// Represents a schema to be used for encoding/decoding smart contract types to/from it's corresponding JSON format.
public enum ContractSchema: Equatable {
    case type(_ value: TypeSchema)
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

    public func decodeInit(contractName: ContractName, schema: ModuleSchema) throws -> String {
        let schema = try schema.initParameterSchema(contractName: contractName)
        return try self.decode(schema: schema)
    }

    public init(json: String, contractName: ContractName, schema: ModuleSchema) throws {
        let schema = try schema.initParameterSchema(contractName: contractName)
        self = try .init(json: json, schema: schema)
    }

    public func decode(receiveName: ReceiveName, schema: ModuleSchema) throws -> String {
        let schema = try schema.updateParameterSchema(receiveName: receiveName)
        return try self.decode(schema: schema)
    }

    public init(json: String, receiveName: ReceiveName, schema: ModuleSchema) throws {
        let schema = try schema.updateParameterSchema(receiveName: receiveName)
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

    public func decode(receiveName: ReceiveName, schema: ModuleSchema) throws -> String {
        let schema = try schema.updateReturnValueSchema(receiveName: receiveName)
        return try self.decode(schema: schema)
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

    public func decode(receiveName: ReceiveName, schema: ModuleSchema) throws -> String {
        let schema = try schema.updateErrorSchema(receiveName: receiveName)
        return try self.decode(schema: schema)
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
public struct InitName: Serialize, Deserialize, Equatable, FromGRPC, ToGRPC {
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

    public var contractName: ContractName { get {
        let index = value.firstIndex(of: "_")! // We know this type always has this in the `init_` prefix
        return ContractName(unchecked: String(value[...index]))
    }}
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
public struct ContractName: Serialize, Deserialize, Equatable {
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
public struct EntrypointName: Serialize, Deserialize, Equatable {
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
public struct ReceiveName: Serialize, Deserialize, Equatable, FromGRPC, ToGRPC {
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
