import Foundation
import NIO

/// Errors happening while trying to convert from generated GRPC type
struct GRPCConversionError: Error {
    let message: String
}

protocol FromGRPC<GRPC> {
    associatedtype GRPC
    /// Initializes the type from the associated GRPC type
    /// - Throws: `GRPCConversionError` if conversion could not be made
    static func fromGRPC(_ gRPC: GRPC) throws -> Self
}

protocol ToGRPC<GRPC> {
    associatedtype GRPC
    /// Converts the type into the associated GRPC type
    func toGRPC() -> GRPC
}

/// Energy is used to count exact execution cost.
/// This cost is then converted to CCD amounts.
public typealias Energy = UInt64

/// Transaction time specified as seconds since unix epoch.
public typealias TransactionTime = UInt64

/// The number of bytes in a sha256 hash
let HASH_BYTES_SIZE: Int = 32
/// The max size of a `Parameter`
let PARAMETER_SIZE_MAX: Int = 65535
/// The max size of a `RegisteredData`
let REGISTERED_DATA_SIZE_MAX: Int = 256
/// The max length of a contract receive name
let FUNC_NAME_MAX: Int = 100

/// Represents an error from not being able to deserialize into a type due to mismatch between the bytes expected/received
public struct ExactSizeError: Error {
    /// The number of bytes attempted to deserialize
    public let actual: Int
    /// The expected number of bytes
    public let expected = HASH_BYTES_SIZE
}

/// Describes a type wrapping `Data`
public protocol HashBytes {
    /// The inner data
    var value: Data { get }
    /// Initializes the `HashBytes` implementation without checking the data
    init(unchecked value: Data)
}

public extension HashBytes {
    /// Creates the type from the passed data
    /// - Throws: `ExactSizeError` if the number of bytes does not match number of bytes expected.
    init(_ data: Data) throws {
        guard data.count == HASH_BYTES_SIZE else {
            throw ExactSizeError(actual: data.count)
        }

        self.init(unchecked: data)
    }

    /// Creates the type from a hex string
    /// - Throws: `DataHexError` if given string is not valid hex
    /// - Throws: `ExactSizeError` if the number of bytes does not match number of bytes expected.
    init(fromHex hex: String) throws {
        let data = try Data(hex: hex)
        try self.init(data)
    }

    var hex: String { value.hex }
}

/// Represents a Concordium transaction hash
public struct TransactionHash: HashBytes, ToGRPC, FromGRPC, Equatable {
    public let value: Data
    public init(unchecked value: Data) {
        self.value = value
    }

    func toGRPC() -> Concordium_V2_TransactionHash {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_TransactionHash) throws -> Self {
        try Self(g.value)
    }
}

/// Represents a Concordium block hash
public struct BlockHash: HashBytes, ToGRPC, FromGRPC, Equatable {
    public let value: Data
    public init(unchecked value: Data) {
        self.value = value
    }

    func toGRPC() -> Concordium_V2_BlockHash {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_BlockHash) throws -> Self {
        try Self(g.value)
    }
}

/// Represents a Concordium smart contract module reference
public struct ModuleReference: HashBytes, Serialize, Deserialize, ToGRPC, FromGRPC, Equatable {
    public let value: Data
    public init(unchecked value: Data) {
        self.value = value
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(value)
    }

    public static func deserialize(_ data: inout Cursor) -> ModuleReference? {
        try? data.read(num: HASH_BYTES_SIZE).map { try Self(Data($0)) }
    }

    func toGRPC() -> Concordium_V2_ModuleRef {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_ModuleRef) throws -> Self {
        try Self(g.value)
    }
}

/// Represents the different versions of WASM modules accepted
public enum WasmVersion: UInt32 {
    case v0
    case v1
}

/// Represents a WASM module as deployed to a Concordium node
public struct WasmModule: Serialize, Deserialize, ToGRPC, FromGRPC, Equatable {
    public var version: WasmVersion
    public var source: Data

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeInteger(version.rawValue) + buffer.writeData(source, lengthPrefix: UInt32.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let version = data.parseUInt(UInt32.self).flatMap(WasmVersion.init),
              let source = data.read(withLengthPrefix: UInt32.self) else { return nil }

        return Self(version: version, source: Data(source))
    }

    func toGRPC() -> Concordium_V2_VersionedModuleSource {
        var g = Concordium_V2_VersionedModuleSource()

        switch version {
        case .v0:
            var src = Concordium_V2_VersionedModuleSource.ModuleSourceV0()
            src.value = source
            g.module = Concordium_V2_VersionedModuleSource.OneOf_Module.v0(src)
        case .v1:
            var src = Concordium_V2_VersionedModuleSource.ModuleSourceV1()
            src.value = source
            g.module = Concordium_V2_VersionedModuleSource.OneOf_Module.v1(src)
        }

        return g
    }

    static func fromGRPC(_ gRPC: Concordium_V2_VersionedModuleSource) throws -> WasmModule {
        switch gRPC.module {
        case let .v0(moduleSourceV0):
            return Self(version: WasmVersion.v0, source: moduleSourceV0.value)
        case let .v1(moduleSourceV1):
            return Self(version: WasmVersion.v1, source: moduleSourceV1.value)
        case .none:
            throw GRPCConversionError(message: "WASM module must specify version")
        }
    }
}

/// A wrapper around a transaction memo
public struct Memo: Serialize, Deserialize, ToGRPC, FromGRPC, Equatable {
    public var value: Data

    public init(_ value: Data) {
        self.value = value
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(value, lengthPrefix: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Memo? {
        data.read(withLengthPrefix: UInt16.self).map { Self(Data($0)) }
    }

    static func fromGRPC(_ gRPC: Concordium_V2_Memo) throws -> Memo {
        Self(gRPC.value)
    }

    func toGRPC() -> Concordium_V2_Memo {
        var m = Concordium_V2_Memo()
        m.value = value
        return m
    }
}

/// Represents a single scheduled transfer in a transfer schedule, i.e. a list of `ScheduledTransfer`s
public struct ScheduledTransfer: Serialize, Deserialize, Equatable {
    /// The time the corresponding ``amount`` will be released
    public var timestamp: TransactionTime
    /// The amount to release
    public var amount: MicroCCDAmount

    public init(timestamp: TransactionTime, amount: MicroCCDAmount) {
        self.timestamp = timestamp
        self.amount = amount
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeInteger(timestamp) + buffer.writeInteger(amount)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let timestamp = data.parseUInt(UInt64.self),
              let amount = data.parseUInt(UInt64.self) else { return nil }
        return Self(timestamp: timestamp, amount: amount)
    }
}

/// Represents a contract address on chain
public struct ContractAddress: Serialize, Deserialize, Equatable, FromGRPC, ToGRPC {
    public var index: UInt64
    public var subindex: UInt64

    public init(index: UInt64, subindex: UInt64) {
        self.index = index
        self.subindex = subindex
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(index) + buffer.writeInteger(subindex)
    }

    public static func deserialize(_ data: inout Cursor) -> ContractAddress? {
        guard let index = data.parseUInt(UInt64.self),
              let subindex = data.parseUInt(UInt64.self) else { return nil }
        return Self(index: index, subindex: subindex)
    }

    func toGRPC() -> Concordium_V2_ContractAddress {
        var g = GRPC()
        g.index = index
        g.subindex = subindex
        return g
    }

    static func fromGRPC(_ gRPC: Concordium_V2_ContractAddress) throws -> Self {
        Self(index: gRPC.index, subindex: gRPC.subindex)
    }
}

/// An error thrown when data supplied to a wrapper does not meet size requirements
public struct DataSizeError: Error {
    /// The size of the supplied data
    let actual: Int
    /// The maximum size allowed
    let max: Int
}

/// Wrapper around ``Data`` supplied to a contract init/receive function
public struct Parameter: Equatable, Serialize, Deserialize, FromGRPC, ToGRPC {
    typealias GRPC = Concordium_V2_Parameter
    public let value: Data

    public init(unchecked value: Data) {
        self.value = value
    }

    /// Initializes a `Parameter` while checking the data
    /// - Throws: ``DataSizeError`` if passed value exceeds the allowed parameter size
    public init(_ value: Data) throws {
        guard value.count <= PARAMETER_SIZE_MAX else {
            throw DataSizeError(actual: value.count, max: PARAMETER_SIZE_MAX)
        }
        self.init(unchecked: value)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(UInt16(value.count)) + buffer.writeData(value)
    }

    public static func deserialize(_ data: inout Cursor) -> Parameter? {
        guard let value = data.read(withLengthPrefix: UInt16.self) else { return nil }
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
}

/// Wrapper around ``Data`` to register on chain
public struct RegisteredData: Equatable, Serialize, Deserialize, FromGRPC, ToGRPC {
    typealias GRPC = Concordium_V2_RegisteredData
    public let value: Data

    public init(unchecked value: Data) {
        self.value = value
    }

    /// Initializes a `Parameter` while checking the associated invariants
    /// - Throws: ``DataSizeError`` if passed value exceeds the allowed parameter size
    public init(_ value: Data) throws {
        guard value.count <= REGISTERED_DATA_SIZE_MAX else {
            throw DataSizeError(actual: value.count, max: REGISTERED_DATA_SIZE_MAX)
        }
        self.init(unchecked: value)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(UInt16(value.count)) + buffer.writeData(value)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let value = data.read(withLengthPrefix: UInt16.self) else { return nil }
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
}

/// Represents an error happening while checking invariants of some string associated with any contract name
public struct ContractNameError: Error {
    /// A message describing the error
    let message: String
}

/// A wrapper around a contract init name
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
        buffer.writeString(value, lengthPrefix: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
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
        buffer.writeString(value, lengthPrefix: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
        return try? Self(parsed)
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
        buffer.writeString(value, lengthPrefix: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
        return try? Self(parsed)
    }
}

/// A wrapper around a receive name, consisting of a ``ContractName`` and an ``EntrypointName``
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
        buffer.writeString(value, lengthPrefix: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
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
