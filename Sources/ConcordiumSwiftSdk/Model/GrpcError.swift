import Foundation

public enum GrpcError: Error, Equatable {
    case unexpectedBase64CheckVersion(expected: UInt8, actual: UInt8)
    case requiredValueMissing(String)
    case unsupportedValue(String)
    case valueOutOfBounds
}
