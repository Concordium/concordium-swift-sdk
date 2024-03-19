import Foundation

public enum GrpcError: Error, Equatable {
    case missingBase58CheckVersion(expected: UInt8, actual: UInt8)
    case missingRequiredValue(String)
    case unsupportedValue(String)
    case valueOutOfBounds
}
