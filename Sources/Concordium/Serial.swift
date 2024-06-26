import Foundation
import NIO

/// Details serialization into format expected by concordium nodes
public protocol Serialize {
    /// Serialize the implementing type into the supplied `ByteBuffer`. Returns the number of bytes written.
    @discardableResult func serializeInto(buffer: inout ByteBuffer) -> Int
}

public extension Serialize {
    /// Serialize the implementing type to `Data`
    func serialize() -> Data {
        var buf = ByteBuffer()
        serializeInto(buffer: &buf)
        return Data(buffer: buf)
    }
}

/// A wrapper around `Data` useful for deserializing the inner data in a sequence of steps.
public struct Cursor {
    private var data: Data

    init(data: Data) {
        self.data = data
    }

    /// Parse an arbitrary `UnsignedInteger` from the data, optionally supplying endianness (defaults to big endian).
    public mutating func parseUInt<UInt: UnsignedInteger>(_: UInt.Type, endianness: Endianness = .big) -> UInt? {
        let expected = MemoryLayout<UInt>.size
        guard var bytes = read(num: expected) else { return nil }

        if endianness == .little { bytes.reverse() }
        return bytes.reduce(0) { soFar, new in (soFar << 8) | UInt(new) }
    }

    /// Read a number of bytes from the inner data.
    public mutating func read(num: Int) -> Data.SubSequence? {
        guard data.count >= num else { return nil }
        defer { self.data = self.data.dropFirst(Int(num)) }

        return data.prefix(num)
    }

    /// Read a number of bytes from the inner data.
    public mutating func read(num: any UnsignedInteger) -> Data.SubSequence? {
        read(num: Int(num))
    }

    /// Read a number of bytes from the inner data, where the number of bytes to read is declared in the data with an `UnsignedInteger` prefix
    public mutating func read<UInt: UnsignedInteger>(withLengthPrefix _: UInt.Type) -> Data.SubSequence? {
        guard let len = parseUInt(UInt.self) else { return nil }
        return read(num: len)
    }

    public mutating func readString<UInt: UnsignedInteger>(withLengthPrefix _: UInt.Type) -> String? {
        guard let bytes = read(withLengthPrefix: UInt.self) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// Whether there is no more data to read
    public var empty: Bool { data.count == 0 }
}

public protocol Deserialize {
    /// Deserializes part of the data in the cursor into the implementing type.
    /// - Returns: The corresponding type, or `nil` if the type could not be parsed due running out of bytes to read.
    static func deserialize(_ data: inout Cursor) -> Self?
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

extension ByteBuffer {
    /// Writes a `Serializable` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize>(_ value: T) -> Int {
        value.serializeInto(buffer: &self)
    }

    /// Writes a list of `Serializable` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize>(list: [T]) -> Int {
        var res = 0
        for item in list {
            res += writeSerializable(item)
        }
        return res
    }

    /// Writes a list of `Serializable` type into the buffer, returning the number of bytes written.
    @discardableResult mutating func writeSerializable<T: Serialize, P: FixedWidthInteger>(list: [T], lengthPrefix _: P.Type) -> Int {
        var res = 0
        res += writeInteger(P(list.count))
        res += writeSerializable(list: list)
        return res
    }

    /// Writes data into buffer with the length prefixed as the supplied `FixedWidthInteger` type
    @discardableResult mutating func writeData<T: FixedWidthInteger>(_ data: Data, lengthPrefix _: T.Type) -> Int {
        var res = 0
        res += writeInteger(T(data.count))
        res += writeData(data)
        return res
    }

    /// Writes data into buffer with the length prefixed as the supplied `FixedWidthInteger` type
    @discardableResult mutating func writeString<T: FixedWidthInteger>(_ value: String, lengthPrefix _: T.Type) -> Int {
        var res = 0
        res += writeInteger(T(value.lengthOfBytes(using: .utf8)))
        res += writeString(value)
        return res
    }
}
