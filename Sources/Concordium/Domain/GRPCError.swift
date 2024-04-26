import Foundation

public enum GRPCError: Error, Equatable {
    case unexpectedBase58CheckVersion(expected: UInt8, actual: UInt8)
    case missingRequiredValue(String)
    case unsupportedValue(String)
    case valueOutOfBounds
}
