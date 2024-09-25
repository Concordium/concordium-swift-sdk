import ConcordiumWalletCrypto
import Foundation
import NIO

/// Energy is used to count exact execution cost.
/// This cost is then converted to CCD amounts.
public typealias Energy = UInt64

/// Transaction time specified as seconds since unix epoch.
public typealias TransactionTime = UInt64

/// The number of bytes in a sha256 hash
public let HASH_BYTES_SIZE: UInt8 = 32
/// The max size of a `RegisteredData`
let REGISTERED_DATA_SIZE_MAX: UInt16 = 256

/// Represents an error from not being able to a value of a given type due to mismatch between the bytes expected/received
public struct ExactSizeError: Error {
    /// The number of bytes given
    public let actual: UInt
    /// The expected number of bytes
    public let expected: UInt

    public init(actual: UInt, expected: UInt = UInt(HASH_BYTES_SIZE)) {
        self.actual = actual
        self.expected = expected
    }
}

extension Date: FromGRPC {
    typealias GRPC = Concordium_V2_Timestamp

    static func fromGRPC(_ g: GRPC) -> Date {
        Date(timeIntervalSince1970: TimeInterval(g.value / 1000))
    }
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
            throw ExactSizeError(actual: UInt(data.count))
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
public struct TransactionHash: HashBytes, ToGRPC, FromGRPC, Equatable, Hashable {
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

extension TransactionHash: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension TransactionHash: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

/// Represents a Concordium block hash
public struct BlockHash: HashBytes, ToGRPC, FromGRPC, Equatable, Hashable {
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

extension BlockHash: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension BlockHash: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

/// Represents the hash of the state of a block
public struct StateHash: HashBytes, ToGRPC, FromGRPC, Equatable, Hashable {
    typealias GRPC = Concordium_V2_StateHash
    public let value: Data
    public init(unchecked value: Data) {
        self.value = value
    }

    func toGRPC() -> GRPC {
        var t = GRPC()
        t.value = value
        return t
    }

    /// Initializes the type from the associated GRPC type
    /// - Throws: `ExactSizeError` if conversion could not be made
    static func fromGRPC(_ g: GRPC) throws -> Self {
        try Self(g.value)
    }
}

/// Represents a Concordium smart contract module reference
public struct ModuleReference: HashBytes, Serialize, Deserialize, ToGRPC, FromGRPC, Equatable, Hashable {
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

extension ModuleReference: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

extension ModuleReference: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

/// Represents the different versions of WASM modules accepted
public enum WasmVersion: UInt8, Serialize, Deserialize, Codable {
    case v0
    case v1

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeInteger(UInt32(rawValue))
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(UInt32.self).flatMap { WasmVersion(rawValue: UInt8($0)) }
    }
}

extension WasmVersion: FromGRPC {
    typealias GRPC = Concordium_V2_ContractVersion

    static func fromGRPC(_ g: GRPC) throws -> WasmVersion {
        try .init(rawValue: UInt8(g.rawValue)) ?! GRPCError.valueOutOfBounds
    }
}

/// Represents a WASM module as deployed to a Concordium node
public struct WasmModule: Serialize, Deserialize, ToGRPC, FromGRPC, Equatable {
    public var version: WasmVersion
    public var source: Data

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeSerializable(version) + buffer.writeData(source, prefixLength: UInt32.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let version = WasmVersion.deserialize(&data),
              let source = data.read(prefixLength: UInt32.self) else { return nil }

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
            throw GRPCError.missingRequiredValue("WASM module must specify version")
        }
    }
}

extension WasmModule: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Self.CodingKeys.self)
        version = try container.decode(WasmVersion.self, forKey: .version)
        source = try Data(hex: container.decode(String.self, forKey: .source))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Self.CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(source.hex, forKey: .source)
    }
}

/// A wrapper around a transaction memo
public struct Memo: Serialize, Deserialize, ToGRPC, FromGRPC, Equatable {
    public var value: Data

    public init(_ value: Data) {
        self.value = value
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(value, prefixLength: UInt16.self)
    }

    public static func deserialize(_ data: inout Cursor) -> Memo? {
        data.read(prefixLength: UInt16.self).map { Self(Data($0)) }
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

extension Memo: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

/// Represents a single scheduled transfer in a transfer schedule, i.e. a list of `ScheduledTransfer`s
public struct ScheduledTransfer: Serialize, Deserialize, Equatable, Codable {
    /// The time the corresponding ``amount`` will be released
    public var timestamp: TransactionTime
    /// The amount to release
    public var amount: CCD

    public init(timestamp: TransactionTime, amount: CCD) {
        self.timestamp = timestamp
        self.amount = amount
    }

    @discardableResult public func serializeInto(buffer: inout ByteBuffer) -> Int {
        buffer.writeInteger(timestamp) + buffer.writeSerializable(amount)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
        guard let timestamp = data.parseUInt(UInt64.self),
              let amount = CCD.deserialize(&data) else { return nil }
        return Self(timestamp: timestamp, amount: amount)
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        timestamp = try container.decode(UInt64.self)
        amount = try container.decode(CCD.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(timestamp)
        try container.encode(amount)
    }
}

extension ScheduledTransfer: FromGRPC {
    typealias GRPC = Concordium_V2_NewRelease

    static func fromGRPC(_ g: GRPC) throws -> ScheduledTransfer {
        try Self(timestamp: g.timestamp.value, amount: .fromGRPC(g.amount))
    }
}

/// Represents a contract address on chain
public typealias ContractAddress = ConcordiumWalletCrypto.ContractAddress

extension ContractAddress: Serialize, Deserialize, FromGRPC, ToGRPC, @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        try JSON(index: index, subindex: subindex).encode(to: encoder)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(JSON.self)
        self = .init(index: value.index, subindex: value.subindex)
    }

    struct JSON: Codable {
        var index: UInt64
        var subindex: UInt64
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

    static func fromGRPC(_ gRPC: Concordium_V2_ContractAddress) -> Self {
        Self(index: gRPC.index, subindex: gRPC.subindex)
    }
}

extension ContractAddress: @retroactive CustomStringConvertible {
    public var description: String {
        "<\(index),\(subindex)>"
    }
}

/// An error thrown when data supplied to a wrapper does not meet size requirements
public struct DataSizeError: Error {
    /// The size of the supplied data
    let actual: UInt
    /// The maximum size allowed
    let max: UInt
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
            throw DataSizeError(actual: UInt(value.count), max: UInt(REGISTERED_DATA_SIZE_MAX))
        }
        self.init(unchecked: value)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(UInt16(value.count)) + buffer.writeData(value)
    }

    public static func deserialize(_ data: inout Cursor) -> Self? {
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
}

extension RegisteredData: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try Data(hex: container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.hex)
    }
}

extension RegisteredData: CustomStringConvertible {
    public var description: String {
        value.hex
    }
}

public typealias InputEncryptedAmount = ConcordiumWalletCrypto.InputEncryptedAmount
public typealias EncryptedAmountAggIndex = UInt64
public typealias SecToPubAmountTransferProof = Data

public typealias CredentialDeploymentInfo = ConcordiumWalletCrypto.CredentialDeploymentInfo

extension CredentialDeploymentInfo: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        let bytes = try! serializeCredentialDeploymentInfo(credInfo: self) // In practice, this will type will never be generated manually, so unwrap is relatively safe...
        return buffer.writeData(Data(bytes))
    }
}

extension CredentialDeploymentInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case arData
        case credId
        case credentialPublicKeys
        case ipIdentity
        case policy
        case proofs
        case revocationThreshold
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(credId.hex, forKey: .credId)
        try container.encode(credentialPublicKeys, forKey: .credentialPublicKeys)
        try container.encode(ipIdentity, forKey: .ipIdentity)
        try container.encode(policy, forKey: .policy)
        try container.encode(proofs.hex, forKey: .proofs)
        try container.encode(revocationThreshold, forKey: .revocationThreshold)

        var arDataJson: [String: ChainArData] = [:]
        for (k, v) in arData {
            arDataJson["\(k)"] = v
        }
        try container.encode(arDataJson, forKey: .arData)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let credId = try Data(hex: container.decode(String.self, forKey: .credId))
        let ipIdentity = try container.decode(UInt32.self, forKey: .ipIdentity)
        let policy = try container.decode(Policy.self, forKey: .policy)
        let proofs = try Data(hex: container.decode(String.self, forKey: .proofs))
        let revocationThreshold = try container.decode(UInt8.self, forKey: .revocationThreshold)

        let parsedArData = try container.decode([String: ChainArData].self, forKey: .arData)
        var arData: [UInt32: ChainArData] = [:]
        for (k, v) in parsedArData {
            let key = UInt32(k)
            arData[key!] = v
        }

        let credentialPublicKeys = try container.decode(CredentialPublicKeys.self, forKey: .credentialPublicKeys)

        self.init(arData: arData, credId: credId, credentialPublicKeys: credentialPublicKeys, ipIdentity: ipIdentity, policy: policy, proofs: proofs, revocationThreshold: revocationThreshold)
    }
}

public typealias BakerKeyPairs = ConcordiumWalletCrypto.BakerKeyPairs

public extension BakerKeyPairs {
    /// Generate a set of baker keys
    static func generate() -> Self {
        generateBakerKeys()
    }
}

/// Represents a protocol version of a Concordium blockchain
public enum ProtocolVersion: FromGRPC {
    case p1 // = 0
    case p2 // = 1
    case p3 // = 2
    case p4 // = 3
    case p5 // = 4
    case p6 // = 5
    case p7 // = 6

    static func fromGRPC(_ gRPC: Concordium_V2_ProtocolVersion) throws -> ProtocolVersion {
        switch gRPC {
        case .protocolVersion1:
            return .p1
        case .protocolVersion2:
            return .p2
        case .protocolVersion3:
            return .p3
        case .protocolVersion4:
            return .p4
        case .protocolVersion5:
            return .p5
        case .protocolVersion6:
            return .p6
        case .protocolVersion7:
            return .p7
        case .UNRECOGNIZED:
            throw GRPCError.valueOutOfBounds
        }
    }
}

public typealias Slot = UInt64
public typealias Round = UInt64
public typealias Epoch = UInt64
public typealias GenesisIndex = UInt32

/// Represents either an account or contract address
public enum Address {
    case account(_ address: AccountAddress)
    case contract(_ address: ContractAddress)
}

extension Address: FromGRPC, ToGRPC {
    typealias GRPC = Concordium_V2_Address

    static func fromGRPC(_ g: GRPC) throws -> Address {
        let address = try g.type ?! GRPCError.missingRequiredValue("type")
        switch address {
        case let .account(v): return .account(.fromGRPC(v))
        case let .contract(v): return .contract(.fromGRPC(v))
        }
    }

    func toGRPC() -> Concordium_V2_Address {
        var g = Concordium_V2_Address()
        switch self {
        case let .account(address):
            g.type = .account(address.toGRPC())
        case let .contract(address):
            g.type = .contract(address.toGRPC())
        }
        return g
    }
}

public struct Versioned<V> {
    public var version: UInt32
    public var value: V

    enum CodingKeys: CodingKey {
        case v
        case value
    }

    public init(version: UInt32, value: V) {
        self.version = version
        self.value = value
    }
}

extension Versioned: Equatable where V: Equatable {}

extension Versioned: Decodable where V: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            version: container.decode(UInt32.self, forKey: .v),
            value: container.decode(V.self, forKey: .value)
        )
    }
}

extension Versioned: Encodable where V: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .v)
        try container.encode(value, forKey: .value)
    }
}
