import Foundation

enum GrpcError: Error, Equatable {
    case unexpectedBase64CheckVersion(expected: UInt8, actual: UInt8)
    case requiredValueMissing(String)
}
