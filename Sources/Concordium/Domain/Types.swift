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
protocol HashBytes {
    var value: Data { get }
    /// Initializes the `HashBytes` implementation without checking the data
    init(value: Data)
}

extension HashBytes {
    /// Creates the type from the passed data
    /// - Throws: `ExactSizeError` if the number of bytes does not match number of bytes expected.
    static func checked(_ data: Data) throws -> Self {
        guard data.count != HASH_BYTES_SIZE else {
            throw ExactSizeError(actual: data.count)
        }

        return Self(value: data)
    }
}

/// Represents a Concordium transaction hash
public struct TransactionHash: HashBytes, ToGRPC, FromGRPC {
    let value: Data

    func toGRPC() -> Concordium_V2_TransactionHash {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_TransactionHash) throws -> Self {
        try checked(g.value)
    }
}

/// Represents a Concordium block hash
public struct BlockHash: HashBytes, ToGRPC, FromGRPC {
    let value: Data

    func toGRPC() -> Concordium_V2_BlockHash {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_BlockHash) throws -> Self {
        try checked(g.value)
    }
}

/// Represents a Concordium smart contract module reference
public struct ModuleReference: HashBytes, ToGRPC, FromGRPC {
    let value: Data

    func toGRPC() -> Concordium_V2_ModuleRef {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: Concordium_V2_ModuleRef) throws -> Self {
        try checked(g.value)
    }
}

/// Represents the different versions of WASM modules accepted
public enum WasmVersion: UInt32 {
    case v0
    case v1
}

/// Represents a WASM module as deployed to a Concordium node
public struct WasmModule: Serialize, Deserialize, ToGRPC, FromGRPC {
    public var version: WasmVersion
    public var source: Data

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeInteger(version.rawValue)
        res += buffer.writeData(source, lengthPrefix: UInt32.self)
        return res
    }

    public func deserialize(_ data: inout Cursor) -> Self? {
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

/// Represents a single scheduled transfer in a transfer schedule, i.e. a list of `ScheduledTransfer`s
public struct ScheduledTransfer: Serialize, Deserialize {
    public var timestamp: TransactionTime
    public var amount: MicroCCDAmount

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeInteger(timestamp)
        res += buffer.writeInteger(amount)
        return res
    }

    public func deserialize(_ data: inout Cursor) -> Self? {
        guard let timestamp = data.parseUInt(UInt64.self),
              let amount = data.parseUInt(UInt64.self) else { return nil }
        return Self(timestamp: timestamp, amount: amount)
    }
}

public struct ParameterSizeError: Error {
    let actual: Int
    let max: Int = PARAMETER_SIZE_MAX
}

public struct Parameter {
    public let value: Data

    /// Initializes a `Parameter` while checking the data
    /// - Throws: `ParameterSizeError` if passed value exceeds the allowed parameter size
    static func checked(_ value: Data) throws -> Self {
        guard value.count <= PARAMETER_SIZE_MAX else {
            throw ParameterSizeError(actual: value.count)
        }
        return Self(value: value)
    }
}

public struct InitName: Serialize, Deserialize {
    public let value: String

    static func checked(_ value: String) throws -> Self {
        // TODO: check invariants
        Self(value: value)
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeString(value, lengthPrefix: UInt16.self)
        return res
    }

    public func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
        return try? Self.checked(parsed)
    }
}

public struct ContractName: Serialize, Deserialize {
    public let value: String

    static func checked(_ value: String) throws -> Self {
        // TODO: check invariants
        Self(value: value)
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeString(value, lengthPrefix: UInt16.self)
        return res
    }

    public func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
        return try? Self.checked(parsed)
    }
}

public struct EntrypointName: Serialize, Deserialize {
    public let value: String

    static func checked(_ value: String) throws -> Self {
        // TODO: check invariants
        Self(value: value)
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeString(value, lengthPrefix: UInt16.self)
        return res
    }

    public func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
        return try? Self.checked(parsed)
    }
}

public struct ReceiveName: Serialize, Deserialize {
    public let value: String

    static func checked(_ value: String) throws -> Self {
        // TODO: check invariants
        Self(value: value)
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        var res = 0
        res += buffer.writeString(value, lengthPrefix: UInt16.self)
        return res
    }

    public func deserialize(_ data: inout Cursor) -> Self? {
        guard let parsed = data.readString(withLengthPrefix: UInt16.self) else { return nil }
        return try? Self.checked(parsed)
    }
}
