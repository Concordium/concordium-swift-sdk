import Foundation
import NIO

/// CIS0 namespace containing CIS-0 related functionality
public enum CIS0 {
    /// Describes a contract standard identifier
    public struct StandardIdentifier {
        /// The ASCII identifier of the contract standard, i.e. CIS-0, CIS-2, ...
        public let id: String

        /// Initialize the value. If the string contains non-ascii characters, nil is returned
        /// - Parameter id: An ascii string
        public init?(id: String) {
            guard id.allSatisfy(\.isASCII) else { return nil }
            self.id = id
        }
    }

    typealias SupportsParam = PrefixListLE<StandardIdentifier, UInt16>

    /// Describes the possible support variants
    public enum SupportResult: Equatable {
        /// The standard is not supported
        case notSupported
        /// The standard is supported
        case supported
        /// The standard is supported by the contracts defined by the `contracts` field.
        case supportedBy(contracts: [ContractAddress])
    }

    typealias SupportsResponse = PrefixListLE<SupportResult, UInt16>

    /// Can be used in any contract that conforms to the CIS0 standard
    public protocol Client: ContractClient {}
}

public extension CIS0.Client {
    /// Query the contract for support of a standard
    /// - Parameter query: The standard to query support for
    /// - Throws: If the client invocation fails
    func supports(_ query: CIS0.StandardIdentifier) async throws -> CIS0.SupportResult {
        try await supports(queries: [query])[0]
    }

    /// Query the contract for support of a list of standards
    /// - Parameter queries: A list of standards to query support for
    /// - Throws: If the client invocation fails
    func supports(queries: [CIS0.StandardIdentifier]) async throws -> [CIS0.SupportResult] {
        let entrypoint = EntrypointName(unchecked: "supports")
        let param = try Parameter(serializable: CIS0.SupportsParam(queries))

        let results = try await view(entrypoint: entrypoint, param: param).deserialize(CIS0.SupportsResponse.self).elements
        guard queries.count == results.count else { throw ListQueryMismatch(queriesCount: UInt(queries.count), responseCount: UInt(results.count)) }
        return results
    }
}

extension CIS0.StandardIdentifier: ContractSerialize {
    public func contractSerialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeString(id, prefix: LengthPrefix<UInt8>(), using: .ascii)
    }
}

extension CIS0.SupportResult: ContractDeserialize {
    public static func contractDeserialize(_ data: inout Cursor) -> CIS0.SupportResult? {
        guard let type = data.parseUInt(UInt8.self) else { return nil }
        switch type {
        case 0: return CIS0.SupportResult.notSupported
        case 1: return CIS0.SupportResult.supported
        case 2:
            guard let contracts = [ContractAddress].contractDeserialize(&data, prefixLength: UInt8.self) else { return nil }
            return CIS0.SupportResult.supportedBy(contracts: contracts)
        default: return nil
        }
    }
}
