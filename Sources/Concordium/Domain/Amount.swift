import BigInt
import Foundation

public enum AmountParseError: Error {
    case invalidInput
    case negativeDecimalCount
    case tooManyFractionalDigits
}

private let ten = BigUInt(10)

/// Representation of an unsigned amount to a precise, but arbitrary precision.
public struct Amount: Equatable {
    /// The amount value given as an arbitrary sized unsigned integer, i.e. without any decimal separator.
    public var value: BigUInt
    /// The number of digits in ``value`` that belong to the fractional/decimal part of the number, including trailing zeros.
    public var decimalCount: UInt16 // type is chosen to ensure that conversion to `Int` never fails (even on 32-bit arch)

    public init(_ value: BigUInt, decimalCount: UInt16) {
        self.value = value
        self.decimalCount = decimalCount
    }

    public init(_ string: String, decimalCount: UInt16, decimalSeparator: String? = nil) throws {
        let sep = Self.resolveDecimalSeparator(decimalSeparator)
        if let sepRange = string.range(of: sep) {
            let wholePart = string[string.startIndex ..< sepRange.lowerBound]
            let fracPart = string[sepRange.upperBound ..< string.endIndex]
            try self.init(wholePart: String(wholePart), fracPart: String(fracPart), decimalCount: decimalCount)
        } else {
            try self.init(wholePart: string, decimalCount: decimalCount)
        }
    }

    private init(wholePart: String, fracPart: String? = nil, decimalCount: UInt16) throws {
        guard let wp = BigUInt(wholePart) else {
            throw AmountParseError.invalidInput
        }
        var value = wp * ten.power(Int(decimalCount))
        if let fracPart {
            guard fracPart.count <= Int(decimalCount) else {
                throw AmountParseError.tooManyFractionalDigits
            }
            guard let fp = BigUInt(fracPart) else {
                throw AmountParseError.invalidInput
            }
            value += fp * ten.power(Int(decimalCount) - fracPart.count)
        } else if wholePart.isEmpty {
            throw AmountParseError.invalidInput
        }
        self.init(value, decimalCount: decimalCount)
    }

    public func withoutTrailingZeros(minDecimalCount: Int) -> Amount {
        var v = value
        var d = decimalCount
        while d > minDecimalCount, v % 10 == 0 {
            v /= 10
            d -= 1
        }
        return Amount(v, decimalCount: d)
    }

    public func format(decimalSeparator: String? = nil) -> String {
        if decimalCount == 0 {
            return String(value)
        }
        let divisor = ten.power(Int(decimalCount))
        let int = String(value / divisor)
        let frac = String(value % divisor)
        let padding = String(repeating: "0", count: Int(decimalCount) - frac.count)
        return "\(int)\(Self.resolveDecimalSeparator(decimalSeparator))\(padding)\(frac)"
    }

    private static func resolveDecimalSeparator(_ provided: String?) -> String {
        provided ?? Locale.current.decimalSeparator ?? "."
    }
}

/// Unsigned amount of CCD.
/// 
/// This is encoded/decoded as a ``String`` when the ``Codable`` protocol is used to make it compatible with other SDK's.
public struct CCD: CustomStringConvertible, Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        // This is decoded as ``String`` to align with serialization in other SDK's
        let value = try container.decode(String.self)
        guard let value = MicroCCDAmount(value) else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected UInt64 string") }
        self.init(microCCD: value)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let microCCD = microCCD else { throw EncodingError.invalidValue(amount.value, EncodingError.Context(codingPath: [], debugDescription: "CCD amount expected to fit inside UInt64")) }
        // This is encoded as ``String`` to align with serialization in other SDK's
        try container.encode("\(microCCD)")
    }

    public static let decimalCount: UInt16 = 6

    public var amount: Amount

    /// Initialize from amount of micro CCD.
    public init(microCCD: MicroCCDAmount) {
        amount = .init(BigUInt(microCCD), decimalCount: Self.decimalCount)
    }

    /// Initialize by parsing a decimal number represented as a string.
    public init(_ string: String, decimalSeparator: String? = nil) throws {
        amount = try .init(string, decimalCount: Self.decimalCount, decimalSeparator: decimalSeparator)
    }

    /// The amount in MicroCCD if it fits within that type, otherwise `nil`.
    public var microCCD: MicroCCDAmount? {
        guard amount.value.bitWidth <= 64 else {
            return nil
        }
        return MicroCCDAmount(amount.value)
    }

    public var description: String {
        format()
    }

    /// Format the amount as a decimal string.
    ///
    /// - Parameters:
    ///   - minDecimalDigits: The smallest number of decimal digits to print (capped by the available number of digits). Trailing zeros beyond this number will be trimmed. Defaults to the available number of digits.
    ///   - decimalSeparator: Symbol printed to separate the integer from the fractional parts of the amount number. Defaults to the value specified by the locale.
    /// - Returns: A string representing the amount in decimal notation.
    public func format(minDecimalDigits: Int? = nil, decimalSeparator: String? = nil) -> String {
        var a = amount
        if let minDecimalDigits {
            a = amount.withoutTrailingZeros(minDecimalCount: minDecimalDigits)
        }
        return a.format(decimalSeparator: decimalSeparator)
    }
}
