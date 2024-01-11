import Foundation

enum GrpcError: Error {
    case unexpectedBase64CheckVersionByte(expected: UInt8, actual: UInt8)
}
