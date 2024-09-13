import Foundation

public enum GRPCError: Error, Equatable {
    case unexpectedBase58CheckVersion(expected: UInt8, actual: UInt8)
    case missingRequiredValue(String)
    case unsupportedValue(String)
    case valueOutOfBounds
}

protocol FromGRPC<GRPC> {
    associatedtype GRPC
    /// Initializes the type from the associated GRPC type
    /// - Throws: `GRPCError` if conversion could not be made
    static func fromGRPC(_ g: GRPC) throws -> Self
}

protocol ToGRPC<GRPC> {
    associatedtype GRPC
    /// Converts the type into the associated GRPC type
    func toGRPC() -> GRPC
}
