import Foundation

infix operator ?!: NilCoalescingPrecedence

/// Throws the `Error` on the right hand side  if the left hand side is `nil`.
func ?!<T>(value: T?, error: @autoclosure () -> Error) throws -> T {
    guard let value else {
        throw error()
    }
    return value
}

enum GrpcError: Error, Equatable {
    case unexpectedBase64CheckVersion(expected: UInt8, actual: UInt8)
    case requiredValueMissing(String)
}
