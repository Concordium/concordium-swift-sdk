import Foundation
import NIO

/// Details serialization into format expected by concordium nodes
public protocol Serialize {
    /// Serialize the implementing type into the supplied ``ByteBuffer``. Returns the number of bytes written.
    @discardableResult func serialize(into buffer: inout ByteBuffer) -> Int
}

public extension Serialize {
    /// Serialize the implementing type to ``Data``
    func serialize() -> Data {
        var buf = ByteBuffer()
        serialize(into: &buf)
        return Data(buffer: buf)
    }

    /// Static version of ``self.serialize(into: inout ByteBuffer)
    static func serialize(_ value: Self, _ buffer: inout ByteBuffer) -> Int {
        value.serialize(into: &buffer)
    }
}

/// A length prefix used when serializing lists/maps
public struct LengthPrefix<U: FixedWidthInteger & UnsignedInteger> {
    /// The endianness used to serialize the prefix
    public let endianness: Endianness

    private init(size _: U.Type, endianness: Endianness) {
        self.endianness = endianness
    }

    /// Construct a prefix config with BE serialization
    public static func BE(size _: U.Type) -> Self { .init(size: U.self, endianness: .big) }
    /// Construct a prefix config with LE serialization
    public static func LE(size _: U.Type) -> Self { .init(size: U.self, endianness: .little) }

    /// Get prefix correspoding to integer value
    public func get(_ num: U) -> Data {
        var buf = ByteBuffer()
        buf.writeInteger(num, endianness: endianness)
        return Data(buffer: buf)
    }

    /// Get prefix for ``Data``
    public func get(for data: Data) -> Data { get(U(data.count)) }
    /// Get prefix for a ``String`` encoding
    public func get(for string: String, using encoding: String.Encoding = .utf8) -> Data { get(U(string.lengthOfBytes(using: encoding))) }
    /// Get prefix for a list of arbitrary elements
    public func get(for list: [Any]) -> Data { get(U(list.count)) }
    /// Get prefix for a map of arbitrary elements
    public func get(for map: [AnyHashable: Any]) -> Data { get(U(map.count)) }

    /// Read the prefix from the cursor
    public func read(in cursor: inout Cursor) -> U? {
        cursor.parseUInt(U.self, endianness: endianness)
    }
}

public extension LengthPrefix where U == UInt8 {
    init() {
        endianness = .big
    }
}

/// A wrapper around ``Data`` useful for deserializing the inner data in a sequence of steps.
public struct Cursor {
    private var data: Data

    init(data: Data) {
        self.data = data
    }

    public var remaining: Data { data }

    /// Parse an arbitrary ``UnsignedInteger`` from the data, optionally supplying endianness (defaults to big endian).
    public mutating func parseUInt<UInt: UnsignedInteger>(_: UInt.Type, endianness: Endianness = .big) -> UInt? {
        let expected = UInt(MemoryLayout<UInt>.size)
        guard var bytes = read(num: expected) else { return nil }

        if endianness == .little { bytes.reverse() }
        return bytes.reduce(0) { soFar, new in (soFar << 8) | UInt(new) }
    }

    /// Parse an arbitrary ``Bool`` from the data
    public mutating func parseBool() -> Bool? {
        guard let res = parseUInt(UInt8.self), res <= 1 else { return nil }
        return res != 0
    }

    /// Read a number of bytes from the inner data.
    public mutating func read(num: any UnsignedInteger) -> Data? {
        guard data.count >= num else { return nil }
        defer { advance(by: num) }

        return data.prefix(Int(num))
    }

    /// Read a number of bytes from the inner data, where the number of bytes to read is declared in the data with an ``UnsignedInteger`` prefix
    public mutating func read<UInt: UnsignedInteger>(prefix: LengthPrefix<UInt>) -> Data? {
        guard let len = prefix.read(in: &self) else { return nil }
        return read(num: len)
    }

    /// Read all bytes from the inner data, completely exhausting the ``Cursor``
    public mutating func readAll() -> Data.SubSequence {
        read(num: UInt(data.count))! // We unwrap as we know the guard which checks the length will pass
    }

    /// Read a string (currently only as UTF8) prefixed with the associated length.
    public mutating func readString<UInt: UnsignedInteger>(prefix: LengthPrefix<UInt>) -> String? {
        guard let bytes = read(prefix: prefix) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Deserialize a deserializable type from the inner data.
    public mutating func deserialize<T>(with deserializer: (_: inout Cursor) -> T?) -> T? {
        deserializer(&self)
    }

    /// Deserialize a list of deserializable types. This will completely exhaust the data in the cursor.
    public mutating func deserialize<T>(listOf _: T.Type, with deserializer: (_: inout Cursor) -> T?) -> [T]? {
        var list: [T] = []
        while !empty {
            guard let s = deserializer(&self) else { return nil }
            list.append(s)
        }
        return list
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    public mutating func deserialize<T, UInt: UnsignedInteger>(listOf _: T.Type, prefix: LengthPrefix<UInt>, with deserializer: (_: inout Cursor) -> T?) -> [T]? {
        guard let len = prefix.read(in: &self) else { return nil }

        var list: [T] = []
        for _ in 0 ..< Int(len) {
            guard let s = deserializer(&self) else { return nil }
            list.append(s)
        }
        return list
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    public mutating func deserialize<K, V>(mapOf _: V.Type, keys _: K.Type, deserializeKey: (_: inout Cursor) -> K?, deserializeValue: (_: inout Cursor) -> V?) -> [K: V]? {
        var map: [K: V] = [:]
        while !empty {
            guard let k = deserializeKey(&self), let v = deserializeValue(&self) else { return nil }
            map[k] = v
        }
        return map
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    public mutating func deserialize<K, V, UInt: UnsignedInteger>(mapOf _: V.Type, keys _: K.Type, prefix: LengthPrefix<UInt>, deserializeKey: (_: inout Cursor) -> K?, deserializeValue: (_: inout Cursor) -> V?) -> [K: V]? {
        guard let len = prefix.read(in: &self) else { return nil }

        var map: [K: V] = [:]
        for _ in 0 ..< Int(len) {
            guard let k = deserializeKey(&self), let v = deserializeValue(&self) else { return nil }
            map[k] = v
        }
        return map
    }

    /// Advande the cursor by a number of bytes
    public mutating func advance(by numBytes: any UnsignedInteger) {
        data = data.dropFirst(Int(numBytes))
    }

    /// Whether there is no more data to read
    public var empty: Bool { data.count == 0 }
}

public extension Cursor {
    /// Deserialize a deserializable type from the inner data.
    mutating func deserialize<T: Deserialize>(_ _: T) -> T? {
        deserialize(with: T.deserialize)
    }

    /// Deserialize a list of deserializable types. This will completely exhaust the data in the cursor.
    mutating func deserialize<T: Deserialize>(listOf _: T.Type) -> [T]? {
        deserialize(listOf: T.self, with: T.deserialize)
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    mutating func deserialize<T: Deserialize, UInt: UnsignedInteger>(listOf _: T.Type, prefix: LengthPrefix<UInt>) -> [T]? {
        deserialize(listOf: T.self, prefix: prefix, with: T.deserialize)
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    mutating func deserialize<K: Deserialize, V: Deserialize>(mapOf _: V.Type, keys _: K.Type) -> [K: V]? {
        deserialize(mapOf: V.self, keys: K.self, deserializeKey: K.deserialize, deserializeValue: V.deserialize)
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    mutating func deserialize<K: Deserialize, V: Deserialize, UInt: UnsignedInteger>(mapOf _: V.Type, keys _: K.Type, prefix: LengthPrefix<UInt>) -> [K: V]? {
        deserialize(mapOf: V.self, keys: K.self, prefix: prefix, deserializeKey: K.deserialize, deserializeValue: V.deserialize)
    }
}

/// Used to represent an error happening when deserializing from byte format.
public struct DeserializeError: Error {
    /// The type attempted to deserialize
    let type: Any.Type
    let expected: UInt
    let actual: UInt

    init<T: Any>(_: T.Type, data: Data) {
        type = T.self
        expected = UInt(MemoryLayout<T>.size)
        actual = UInt(data.count)
    }
}

public protocol Deserialize {
    /// Deserializes part of the data in the cursor into the implementing type.
    /// - Returns: The corresponding type, or `nil` if the type could not be parsed due running out of bytes to read.
    static func deserialize(_ data: inout Cursor) -> Self?
}

public extension Deserialize {
    /// Deserializes the data into the implementing type.
    /// - Returns: The corresponding type, or `nil` if the type could not be parsed due to mismatch between the expected/found number of bytes in the buffer.
    static func deserialize(_ data: Data) throws -> Self {
        var parser = Cursor(data: data)
        guard let result = Self.deserialize(&parser), parser.empty else { throw DeserializeError(Self.self, data: data) }
        return result
    }
}

extension UInt8: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension UInt16: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension UInt32: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension UInt64: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension ByteBuffer {
    /// Writes some type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T>(_ value: T, with serializer: (_: T, _: inout ByteBuffer) -> Int) -> Int {
        serializer(value, &self)
    }

    /// Writes a list of some type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T>(list: [T], with serializer: (_: T, _: inout ByteBuffer) -> Int) -> Int {
        var res = 0
        for item in list {
            res += writeSerializable(item, with: serializer)
        }
        return res
    }

    /// Writes a map of some type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<K, V>(map: [K: V], serializeKey: (_: K, _: inout ByteBuffer) -> Int, serializeValue: (_: V, _: inout ByteBuffer) -> Int) -> Int {
        var res = 0
        for (key, value) in map {
            res += writeSerializable(key, with: serializeKey)
            res += writeSerializable(value, with: serializeValue)
        }
        return res
    }

    /// Writes a list of some type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T, P: UnsignedInteger & FixedWidthInteger>(list: [T], prefix: LengthPrefix<P>, with serializer: (_: T, _: inout ByteBuffer) -> Int) -> Int {
        var res = 0
        res += writeData(prefix.get(for: list))
        res += writeSerializable(list: list, with: serializer)
        return res
    }

    /// Writes a map of some type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<K, V, P: UnsignedInteger & FixedWidthInteger>(map: [K: V], prefix: LengthPrefix<P>, serializeKey: (_: K, _: inout ByteBuffer) -> Int, serializeValue: (_: V, _: inout ByteBuffer) -> Int) -> Int {
        var res = 0
        res += writeData(prefix.get(for: map))
        res += writeSerializable(map: map, serializeKey: serializeKey, serializeValue: serializeValue)
        return res
    }

    /// Writes data into buffer with the length prefixed as the supplied ``FixedWidthInteger`` type
    @discardableResult mutating func writeData<P: UnsignedInteger & FixedWidthInteger>(_ data: Data, prefix: LengthPrefix<P>) -> Int {
        var res = 0
        res += writeData(prefix.get(for: data))
        res += writeData(data)
        return res
    }

    /// Writes data into buffer with the length prefixed as the supplied ``FixedWidthInteger`` type
    @discardableResult mutating func writeString<P: UnsignedInteger & FixedWidthInteger>(_ value: String, prefix: LengthPrefix<P>, using encoding: String.Encoding = .utf8) -> Int {
        var res = 0
        res += writeData(prefix.get(for: value, using: encoding))
        res += writeString(value)
        return res
    }

    /// Writes bool into buffer
    @discardableResult mutating func writeBool(_ value: Bool) -> Int {
        writeInteger(value ? 1 : 0, as: UInt8.self)
    }
}

extension ByteBuffer {
    /// Writes a ``Serialize`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize>(_ value: T) -> Int {
        writeSerializable(value, with: T.serialize)
    }

    /// Writes a list of ``Serialize`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize>(list: [T]) -> Int {
        writeSerializable(list: list, with: T.serialize)
    }

    /// Writes a map of ``Serializa`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<K: Serialize, V: Serialize>(map: [K: V]) -> Int {
        writeSerializable(map: map, serializeKey: K.serialize, serializeValue: V.serialize)
    }

    /// Writes a list of ``Serialize`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize, P: UnsignedInteger & FixedWidthInteger>(list: [T], prefix: LengthPrefix<P>) -> Int {
        writeSerializable(list: list, prefix: prefix, with: T.serialize)
    }

    /// Writes a map of ``Serialize`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<K: Serialize, V: Serialize, P: UnsignedInteger & FixedWidthInteger>(map: [K: V], prefix: LengthPrefix<P>) -> Int {
        writeSerializable(map: map, prefix: prefix, serializeKey: K.serialize, serializeValue: V.serialize)
    }
}

public extension Array where Element: Serialize {
    /// Serialize list elements
    func serialize() -> Data {
        var buf = ByteBuffer()
        let _ = serialize(into: &buf)
        return Data(buffer: buf)
    }

    /// Serialize list elements into the buffer
    func serialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeSerializable(list: self, with: Element.serialize)
    }

    /// Serializes the list with the number of elements prefixed into the buffer
    /// - Parameters:
    ///   - buffer: The buffer to write the data to
    ///   - elements: The serializable elements to write
    ///   - _: the integer size used to describe the number of elements serialized.
    func serialize<P: UnsignedInteger & FixedWidthInteger>(into buffer: inout NIOCore.ByteBuffer, prefixLength _: P.Type) -> Int {
        buffer.writeSerializable(list: self, prefix: LengthPrefix.BE(size: P.self), with: Element.serialize)
    }

    /// Serializes the list with the number of elements prefixed
    /// - Parameters:
    ///   - elements: The serializable elements to write
    ///   - _: the integer size used to describe the number of elements serialized.
    func serialize<P: UnsignedInteger & FixedWidthInteger>(prefixLength _: P.Type) -> Data {
        var buf = ByteBuffer()
        let _ = serialize(into: &buf, prefixLength: P.self)
        return Data(buffer: buf)
    }
}

public extension Array where Element: Deserialize {
    /// Deserialize the data into a list of ``Element``
    /// - Parameter data: the data to deserialize
    /// - Throws: if the data does not fit the expected value
    static func deserialize(_ data: Data) throws -> [Element] {
        var cursor = Cursor(data: data)
        guard let elements = deserialize(&cursor), cursor.empty else { throw DeserializeError(Self.self, data: data) }
        return elements
    }

    /// Deserialize the data into a list of ``Element``
    /// - Parameter data: the data to deserialize
    /// - Returns the list or nil if not enough data was available to deserialize the a list of ``Element``s
    static func deserialize(_ data: inout Cursor) -> [Element]? {
        data.deserialize(listOf: Element.self, with: Element.deserialize)
    }

    /// Deserialize data into a list of ``Element``s
    /// - Parameters:
    ///   - data: The data to deserialize
    ///   - _: the integer size used to describe the number of elements serialized.
    static func deserialize<P: UnsignedInteger & FixedWidthInteger>(_ data: inout Cursor, prefixLength _: P.Type) -> [Element]? {
        data.deserialize(listOf: Element.self, prefix: LengthPrefix.BE(size: P.self), with: Element.deserialize)
    }

    /// Deserialize data into a list of ``Element``s
    /// - Parameters:
    ///   - data: The data to deserialize
    ///   - _: the integer size used to describe the number of elements serialized.
    static func deserialize<P: UnsignedInteger & FixedWidthInteger>(_ data: Data, prefixLength _: P.Type) throws -> [Element] {
        var parser = Cursor(data: data)
        guard let result = Self.deserialize(&parser, prefixLength: P.self), parser.empty else { throw DeserializeError(Self.self, data: data) }
        return result
    }
}

public extension Dictionary where Key: Serialize, Value: Serialize {
    /// Serialize dictionary
    func serialize() -> Data {
        var buf = ByteBuffer()
        let _ = serialize(into: &buf)
        return Data(buffer: buf)
    }

    /// Serialize dictionary into the supplied buffer
    func serialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeSerializable(map: self, serializeKey: Key.serialize, serializeValue: Value.serialize)
    }

    /// Serializes the dictionary with the number of pairs prefixed into the buffer
    /// - Parameters:
    ///   - buffer: The buffer to write the data to
    ///   - elements: The serializable elements to write
    ///   - _: the integer size used to describe the number of pairs serialized.
    func serialize<P: UnsignedInteger & FixedWidthInteger>(into buffer: inout NIOCore.ByteBuffer, prefixLength _: P.Type) -> Int {
        buffer.writeSerializable(map: self, prefix: LengthPrefix.BE(size: P.self), serializeKey: Key.serialize, serializeValue: Value.serialize)
    }

    /// Serializes the dictionary with the number of pairs prefixed
    /// - Parameters:
    ///   - elements: The serializable elements to write
    ///   - _: the integer size used to describe the number of pairs serialized.
    func serialize<P: UnsignedInteger & FixedWidthInteger>(prefixLength _: P.Type) -> Data {
        var buf = ByteBuffer()
        let _ = serialize(into: &buf, prefixLength: P.self)
        return Data(buffer: buf)
    }
}

public extension Dictionary where Key: Deserialize, Value: Deserialize {
    /// Deserialize the data into a dictionary of ``Key``, ``Value`` pairs
    /// - Parameter data: the data to deserialize
    /// - Throws: if the data does not fit the expected value
    static func deserialize(_ data: Data) throws -> [Key: Value] {
        var cursor = Cursor(data: data)
        guard let elements = deserialize(&cursor), cursor.empty else { throw DeserializeError(Self.self, data: data) }
        return elements
    }

    /// Deserialize the data into a dictionary of ``Key``, ``Value`` pairs
    /// - Parameter data: the data to deserialize
    /// - Returns the list or nil if not enough data was available to deserialize the a list of ``Element``s
    static func deserialize(_ data: inout Cursor) -> [Key: Value]? {
        data.deserialize(mapOf: Value.self, keys: Key.self, deserializeKey: Key.deserialize, deserializeValue: Value.deserialize)
    }

    /// Deserialize data into a ``[Key:Value]``
    /// - Parameters:
    ///   - data: The data to deserialize
    ///   - _: the integer size used to describe the number of pairs serialized.
    static func deserialize<P: UnsignedInteger & FixedWidthInteger>(_ data: inout Cursor, prefixLength _: P.Type) -> [Key: Value]? {
        data.deserialize(mapOf: Value.self, keys: Key.self, prefix: LengthPrefix.BE(size: P.self), deserializeKey: Key.deserialize, deserializeValue: Value.deserialize)
    }

    /// Deserialize data into a ``[Key:Value]``
    /// - Parameters:
    ///   - data: The data to deserialize
    ///   - _: the integer size used to describe the number of elements serialized.
    static func deserialize<P: UnsignedInteger & FixedWidthInteger>(_ data: Data, prefixLength _: P.Type) throws -> [Key: Value] {
        var parser = Cursor(data: data)
        guard let result = Self.deserialize(&parser, prefixLength: P.self), parser.empty else { throw DeserializeError(Self.self, data: data) }
        return result
    }
}
