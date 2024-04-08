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

    public var decimals: Int

    public static func parse(input: String, decimals: Int, decimalSeparator: String = ".") throws -> Amount {
        guard decimals >= 0 else {
            throw AmountParseError.negativeDecimals
        }

        let sep = decimalSeparator[decimalSeparator.startIndex]
        if let idx = input.firstIndex(of: sep) {
            let wholePart = input[input.startIndex ..< idx]
            let idx1 = input.index(idx, offsetBy: 1)
            let fracPart = input[idx1 ..< input.endIndex]
            guard let wholePartInt = BigUInt(wholePart), let fracPartInt = BigUInt(fracPart) else {
                throw AmountParseError.invalidInput
            }
            guard fracPart.count <= decimals else {
                throw AmountParseError.fractionPartTooLong
            }
            let multipliedWholeInt = wholePartInt * ten.power(decimals)
            let multipliedFractionInt = fracPartInt * ten.power(decimals - fracPart.count)
            return Amount(intValue: multipliedWholeInt + multipliedFractionInt, decimals: decimals)
        }
        guard let wholePartInt = BigUInt(input) else {
            throw AmountParseError.invalidInput
        }
        return Amount(
            intValue: wholePartInt * ten.power(decimals),
            decimals: decimals
        )
    }

    public func format(minDecimalDigits: Int, decimalSeparator: String = ".") -> String {
        var v = intValue
        var d = decimals
        while d > minDecimalDigits, v % 10 == 0 {
            v /= 10
            d -= 1
        }
        return Self.format(value: v, subunitPrecision: d, decimalSeparator: decimalSeparator)
    }

    public static func format(value: BigUInt, subunitPrecision: Int, decimalSeparator: String) -> String {
        if subunitPrecision == 0 {
            return String(value)
        }
        let divisor = ten.power(subunitPrecision)
        let int = String(value / divisor)
        let frac = String(value % divisor)
        let padding = String(repeating: "0", count: subunitPrecision - frac.count)
        return "\(int)\(decimalSeparator)\(padding)\(frac)"
    }
}

public struct CCD: CustomStringConvertible {
    private static let decimals = 6

    public var amount: Amount

    public init(microCCD: MicroCCDAmount) {
        amount = Amount(intValue: BigUInt(microCCD), decimals: Self.decimals)
    }

    public init(_ string: String) throws {
        amount = try Amount.parse(input: string, decimals: Self.decimals)
    }

    public var description: String {
        format(minDecimalDigits: 0)
    }

    public func format(minDecimalDigits: Int = 0) -> String {
        amount.format(minDecimalDigits: minDecimalDigits)
    }
}
