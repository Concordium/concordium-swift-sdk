import Foundation
import NIO

/// Namespace for ULEB128 functionality.
enum ULEB128 {
    /// Encode the unsigned integer as ULEB128.
    /// - Parameters:
    ///   - value: The value to encode
    ///   - into: The `ByteBuffer` to encode the value into
    /// - Returns: The encoded value as ``Data``
    static func encode<U: UnsignedInteger>(_ value: U, into buffer: inout ByteBuffer) -> Int {
        var value = value
        var encodedBytes: [UInt8] = []

        repeat {
            var byte = UInt8(value & 0x7F) // Extract the lower 7 bits
            value >>= 7 // Shift value to the right by 7 bits
            if value != 0 {
                byte |= 0x80 // Set the most significant bit if there's more data
            }
            encodedBytes.append(byte)
        } while value != 0

        return buffer.writeData(encodedBytes)
    }

    /// Encode the unsigned integer as ULEB128.
    /// - Parameters:
    ///   - value: The value to encode
    /// - Returns: The encoded value as ``Data``
    static func encode<U: UnsignedInteger>(_ value: U) -> Data {
        var buf = ByteBuffer()
        let _ = encode(value, into: &buf)
        return Data(buffer: buf)
    }

    ///  Decode the ULEB128 encoded data into the unsigned integer type
    /// - Parameters:
    ///   - data: the data to decode
    ///   - _: the unsigned integer type to decode as
    /// - Returns: A corresponding unsigned integer.
    static func decode<U: UnsignedInteger>(_ data: inout Cursor, as _: U.Type) -> U {
        var value: UInt = 0
        var shift: UInt = 0

        var bytesRead: UInt = 0
        for byte in data.remaining {
            bytesRead += 1
            let byteValue = UInt(byte & 0x7F) // Extract the lower 7 bits
            value |= (byteValue << shift) // Add the shifted byte to the result
            if (byte & 0x80) == 0 { // Check if the most significant bit is clear (end of data)
                break
            }
            shift += 7 // Increase the shift for the next byte
        }

        data.advance(by: bytesRead)

        return U(value)
    }

    ///  Decode the ULEB128 encoded data into the unsigned integer type
    /// - Parameters:
    ///   - data: the data to decode
    ///   - _: the unsigned integer type to decode as
    /// - Returns: A corresponding unsigned integer. If the data is not completely exhausted while decoding, nil is returned.
    ///   For partial decoding, use the ``Cursor`` variant of this function.
    static func decode<U: UnsignedInteger>(_ data: Data, as _: U.Type) -> U? {
        var cursor = Cursor(data: data)
        let amount = decode(&cursor, as: U.self)
        guard cursor.empty else { return nil }
        return amount
    }
}
