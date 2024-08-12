import Foundation
import NIO

/// Details serialization into format expected by concordium nodes
public protocol Serialize {
    /// Serialize the implementing type into the supplied ``ByteBuffer``. Returns the number of bytes written.
    @discardableResult func serializeInto(buffer: inout ByteBuffer) -> Int
}

public extension Serialize {
    /// Serialize the implementing type to ``Data``
    func serialize() -> Data {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf)
        return Data(buffer: buf)
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
    public mutating func read<UInt: UnsignedInteger>(withLengthPrefix _: UInt.Type) -> Data? {
        guard let len = parseUInt(UInt.self) else { return nil }
        return read(num: len)
    }

    /// Read all bytes from the inner data, completely exhausting the ``Cursor``
    public mutating func readAll() -> Data.SubSequence {
        read(num: UInt(data.count))! // We unwrap as we know the guard which checks the length will pass
    }

    /// Read a string prefixed with the associated length.
    public mutating func readString<UInt: UnsignedInteger>(lengthPrefix _: UInt.Type) -> String? {
        guard let bytes = read(withLengthPrefix: UInt.self) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Deserialize a deserializable type from the inner data.
    public mutating func deserialize<T: Deserialize>(_ _: T) -> T? {
        T.deserialize(&self)
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    public mutating func deserialize<T: Deserialize, UInt: UnsignedInteger>(listOf _: T.Type, lengthPrefix _: UInt.Type) -> [T]? {
        guard let length = parseUInt(UInt.self) else { return nil }

        var list: [T] = []
        for _ in 0 ..< Int(length) {
            guard let s = T.deserialize(&self) else { return nil }
            list.append(s)
        }
        return list
    }

    /// Deserialize a list of deserializable types, prefixed with an associated length from the inner data.
    public mutating func deserialize<K: Deserialize, V: Deserialize, UInt: UnsignedInteger>(mapOf _: V.Type, keys _: K.Type, lengthPrefix _: UInt.Type) -> [K: V]? {
        guard let length = parseUInt(UInt.self) else { return nil }

        var map: [K: V] = [:]
        for _ in 0 ..< Int(length) {
            guard let k = K.deserialize(&self), let v = V.deserialize(&self) else { return nil }
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

/// Used to represent an error happening when deserializing from byte format.
public struct DeserializeError: Error {
    /// The type attempted to deserialize
    let type: any Deserialize.Type
}

public protocol Deserialize {
    /// Deserializes part of the data in the cursor into the implementing type.
    /// - Returns: The corresponding type, or `nil` if the type could not be parsed due running out of bytes to read.
    static func deserialize(_ data: inout Cursor) -> Self? // TODO: refactor this to throw instead of returning optional
}

public extension Deserialize {
    /// Deserializes the data into the implementing type.
    /// - Returns: The corresponding type, or `nil` if the type could not be parsed due to mismatch between the expected/found number of bytes in the buffer.
    static func deserialize(_ data: Data) -> Self? {
        var parser = Cursor(data: data)
        let result = Self.deserialize(&parser)
        guard parser.empty else { return nil }
        return result
    }
}

extension UInt8: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension UInt16: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension UInt32: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension UInt64: Serialize, Deserialize {
    public static func deserialize(_ data: inout Cursor) -> Self? {
        data.parseUInt(Self.self)
    }

    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeInteger(self)
    }
}

extension ByteBuffer {
    /// Writes a ``Serializable`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize>(_ value: T) -> Int {
        value.serializeInto(buffer: &self)
    }

    /// Writes a list of ``Serializable`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize>(list: [T]) -> Int {
        var res = 0
        for item in list {
            res += writeSerializable(item)
        }
        return res
    }

    /// Writes a map of ``Serializable`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<K: Serialize, V: Serialize>(map: [K: V]) -> Int {
        var res = 0
        for (key, value) in map {
            res += writeSerializable(key)
            res += writeSerializable(value)
        }
        return res
    }

    /// Writes a list of ``Serializable`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize, P: FixedWidthInteger>(list: [T], lengthPrefix _: P.Type) -> Int {
        var res = 0
        res += writeInteger(P(list.count))
        res += writeSerializable(list: list)
        return res
    }

    /// Writes a map of ``Serializable`` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<K: Serialize, V: Serialize, P: FixedWidthInteger>(map: [K: V], lengthPrefix _: P.Type) -> Int {
        var res = 0
        res += writeInteger(P(map.count))
        res += writeSerializable(map: map)
        return res
    }

    /// Writes data into buffer with the length prefixed as the supplied ``FixedWidthInteger`` type
    @discardableResult mutating func writeData<T: FixedWidthInteger>(_ data: Data, lengthPrefix _: T.Type) -> Int {
        var res = 0
        res += writeInteger(T(data.count))
        res += writeData(data)
        return res
    }

    /// Writes data into buffer with the length prefixed as the supplied ``FixedWidthInteger`` type
    @discardableResult mutating func writeString<T: FixedWidthInteger>(_ value: String, lengthPrefix _: T.Type) -> Int {
        var res = 0
        res += writeInteger(T(value.lengthOfBytes(using: .utf8)))
        res += writeString(value)
        return res
    }

    /// Writes bool into buffer
    @discardableResult mutating func writeBool(_ value: Bool) -> Int {
        writeInteger(value ? 1 : 0, as: UInt8.self)
    }
}
