import Foundation

infix operator ?!: NilCoalescingPrecedence

/// Expect the value of the left hand side to be not `nil` by throwing  the error on the right hand if it isn't.
///
/// For example, expression
/// ```
/// computeSomething() ?! MyError.computationFailed
/// ```
/// evaluates to the result of `computeSomething()`unless that result is `nil`
/// in which case it throws the custom error `MyError.computationFailed`.
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
