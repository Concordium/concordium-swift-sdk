import BigInt
import Foundation

public enum AmountParseError: Error {
    case invalidInput
    case negativeDecimalCount
    case tooManyFractionalDigits
}

private let ten = BigUInt(10)

public struct Amount: Equatable {
    public var intValue: BigUInt
    public var decimalCount: Int

    public init(_ intValue: BigUInt, decimalCount: Int) {
        self.intValue = intValue
        self.decimalCount = decimalCount
    }

    public init(_ string: String, decimalCount: Int, decimalSeparator: String? = nil) throws {
        guard decimalCount >= 0 else {
            throw AmountParseError.negativeDecimalCount
        }
        let sep = Self.resolveDecimalSeparator(decimalSeparator)
        if let sepIdx = string.firstIndex(of: sep[sep.startIndex]) {
            let wholePart = string[string.startIndex ..< sepIdx]
            let sepIdx1 = string.index(sepIdx, offsetBy: 1)
            let fracPart = string[sepIdx1 ..< string.endIndex]
            try self.init(wholePart: String(wholePart), fracPart: String(fracPart), decimalCount: decimalCount)
        } else {
            try self.init(wholePart: string, decimalCount: decimalCount)
        }
    }

    private init(wholePart: String, fracPart: String? = nil, decimalCount: Int) throws {
        guard let wp = BigUInt(wholePart) else {
            throw AmountParseError.invalidInput
        }
        var intValue = wp * ten.power(decimalCount)
        if let fracPart {
//            if fracPart.isEmpty {
//                throw AmountParseError.trailingDecimalSeparator
//            }
            guard fracPart.count <= decimalCount else {
                throw AmountParseError.tooManyFractionalDigits
            }
            guard let fp = BigUInt(fracPart) else {
                throw AmountParseError.invalidInput
            }
            intValue += fp * ten.power(decimalCount - fracPart.count)
        } else if wholePart.isEmpty {
            throw AmountParseError.invalidInput
        }
        self.init(intValue, decimalCount: decimalCount)
    }

    public func withoutTrailingZeros(minDecimalCount: Int) -> Amount {
        var v = intValue
        var d = decimalCount
        while d > minDecimalCount, v % 10 == 0 {
            v /= 10
            d -= 1
        }
        return Amount(v, decimalCount: d)
    }

    public func format(decimalSeparator: String? = nil) -> String {
        if decimalCount == 0 {
            return String(intValue)
        }
        let divisor = ten.power(decimalCount)
        let int = String(intValue / divisor)
        let frac = String(intValue % divisor)
        let padding = String(repeating: "0", count: decimalCount - frac.count)
        return "\(int)\(Self.resolveDecimalSeparator(decimalSeparator))\(padding)\(frac)"
    }

    private static func resolveDecimalSeparator(_ provided: String?) -> String {
        provided ?? Locale.current.decimalSeparator ?? "."
    }
}

public struct CCD: CustomStringConvertible {
    public static let decimalCount = 6

    public var amount: Amount

    public init(microCCD: MicroCCDAmount) {
        amount = .init(BigUInt(microCCD), decimalCount: Self.decimalCount)
    }

    public init(_ string: String) throws {
        amount = try .init(string, decimalCount: Self.decimalCount)
    }

    public var microCCDAmount: MicroCCDAmount {
        MicroCCDAmount(amount.intValue)
    }

    public var description: String {
        format()
    }

    public func format(minDecimalDigits: Int? = nil, decimalSeparator: String? = nil) -> String {
        var a = amount
        if let minDecimalDigits {
            a = amount.withoutTrailingZeros(minDecimalCount: minDecimalDigits)
        }
        return a.format(decimalSeparator: decimalSeparator)
    }
}
