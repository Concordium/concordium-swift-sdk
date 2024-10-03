import Foundation

struct ULEB128 {
    static func encode<U: UnsignedInteger>(_ value: U) -> Data {
        var value = value
        var encodedBytes: [UInt8] = []

        repeat {
            var byte = UInt8(value & 0x7F)  // Extract the lower 7 bits
            value >>= 7                     // Shift value to the right by 7 bits
            if value != 0 {
                byte |= 0x80                // Set the most significant bit if there's more data
            }
            encodedBytes.append(byte)
        } while value != 0

        return Data(encodedBytes)
    }

    static func decode<U: UnsignedInteger>(_ data: Data) -> U {
        var value: UInt = 0
        var shift: UInt = 0

        for byte in data {
            let byteValue = UInt(byte & 0x7F)    // Extract the lower 7 bits
            value |= (byteValue << shift)        // Add the shifted byte to the result
            if (byte & 0x80) == 0 {              // Check if the most significant bit is clear (end of data)
                break
            }
            shift += 7                           // Increase the shift for the next byte
        }

        return U(value)
    }
}
