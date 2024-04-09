import BigInt
import Foundation

public enum AmountParseError: Error {
    case invalidInput
    case negativeDecimals
    case fractionPartTooLong
    case inputTooLarge
}

private let ten = BigUInt(10)

public struct Amount {
    public var intValue: BigUInt
    public var decimalCount: Int

    public init(intValue: BigUInt, decimalCount: Int) {
        self.intValue = intValue
        self.decimalCount = decimalCount
    }

    public init(input: String, decimalCount: Int, decimalSeparator: String? = nil) throws {
        guard decimalCount >= 0 else {
            throw AmountParseError.negativeDecimals
        }
        let sep = Self.resolveDecimalSeparator(decimalSeparator)
        if let sepIdx = input.firstIndex(of: sep[sep.startIndex]) {
            let wholePart = input[input.startIndex ..< sepIdx]
            let sepIdx1 = input.index(sepIdx, offsetBy: 1)
            let fracPart = input[sepIdx1 ..< input.endIndex]
            try self.init(wholePart: wholePart, fracPart: fracPart, decimalCount: decimalCount)
        } else {
            try self.init(wholePart: input, decimalCount: decimalCount)
        }
    }

    private init(wholePart: any StringProtocol, fracPart: (any StringProtocol)? = nil, decimalCount: Int) throws {
        guard let wp = BigUInt(wholePart) else {
            throw AmountParseError.invalidInput
        }
        var intValue = wp * ten.power(decimalCount)
        if let fracPart {
            guard let fp = BigUInt(fracPart) else {
                throw AmountParseError.invalidInput
            }
            intValue += fp * ten.power(decimalCount - fracPart.count)
        }
        self.init(intValue: intValue, decimalCount: decimalCount)
    }

    public func format(minDecimalDigits: Int, decimalSeparator: String? = nil) -> String {
        var v = intValue
        var d = decimalCount
        while d > minDecimalDigits, v % 10 == 0 {
            v /= 10
            d -= 1
        }
        return Self.format(value: v, subunitPrecision: d, decimalSeparator: decimalSeparator)
    }

    public static func format(value: BigUInt, subunitPrecision: Int, decimalSeparator: String? = nil) -> String {
        if subunitPrecision == 0 {
            return String(value)
        }
        let divisor = ten.power(subunitPrecision)
        let int = String(value / divisor)
        let frac = String(value % divisor)
        let padding = String(repeating: "0", count: subunitPrecision - frac.count)
        return "\(int)\(resolveDecimalSeparator(decimalSeparator))\(padding)\(frac)"
    }

    private static func resolveDecimalSeparator(_ provided: String?) -> String {
        provided ?? Locale.current.decimalSeparator ?? "."
    }
}

public struct CCD: CustomStringConvertible {
    private static let decimalCount = 6

    public var amount: Amount

    public init(microCCD: MicroCCDAmount) {
        amount = .init(intValue: BigUInt(microCCD), decimalCount: Self.decimalCount)
    }

    public init(_ string: String) throws {
        amount = try .init(input: string, decimalCount: Self.decimalCount)
    }

    public var microCCDAmount: MicroCCDAmount {
        MicroCCDAmount(amount.intValue)
    }

    public var description: String {
        format(minDecimalDigits: 0)
    }

    public func format(minDecimalDigits: Int = 0) -> String {
        amount.format(minDecimalDigits: minDecimalDigits)
    }
}
