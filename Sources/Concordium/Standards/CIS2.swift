import Foundation
import BigInt
import NIO

public struct ListQueryMismatch: Error {
    /// The number of input query parameters
    let queriesCount: UInt
    /// The number of return values in the response
    let responseCount: UInt
}

/// Namespace for any CIS2 related type
public struct CIS2 {
    /// Represents a token amount of arbitrary precision
    public struct TokenAmount {
        /// The inner amount
        public let amount: BigUInt
    }

    struct TokenAmounts {
        let amounts: [TokenAmount]
    }

    /// A token ID for a CIS2 contract token
    public typealias TokenID = Data

    struct TokenMetadataQuery {
        let ids: [TokenID]
    }

    /// Represents a token address, i.e. a contract + token ID
    public struct TokenAddress {
        /// The contract address holding the token
        public let contract: ContractAddress
        /// The token ID within the associated contract
        public let id: TokenID
    }

    /// Represents a token metadata URL for a CIS2 token
    public struct TokenMetadata {
        /// The url
        public let url: URL
        /// An optional checksum for the data at the `url`
        public let checksum: Data?
    }

    struct TokensMetadata {
        let metadata: [TokenMetadata]
    }

    /// Data for a ``CIS2.Contract.balanceOf`` query
    public struct BalanceOfQuery {
        /// The token ID to query
        public let tokenId: Data
        /// The ``Address`` to query the balance for
        public let address: Address
    }

    struct BalanceOfQueries {
        let queries: [BalanceOfQuery]
    }

    /// Represents an arbitrary CIS2 contract
    public struct Contract: ContractClient {
        public let name: ContractName
        public let address: ContractAddress
        public let client: NodeClient

        public init(client: NodeClient, name: ContractName, address: ContractAddress) {
            self.client = client
            self.address = address
            self.name = name
        }

        /// Query the contract for the balance of an ``Address`` for a specific token
        /// - Parameter queries: the query holding the ``Address`` and ``TokenID``
        /// - Throws: if the query fails
        public func balanceOf(_ query: BalanceOfQuery) async throws -> TokenAmount {
            return try await balanceOf(queries: [query])[0]
        }

        /// Query the contract for a list of balances corresponding to a list of ``Address`` for a specific token
        /// - Parameter queries: the list of queries holding the ``Address`` and ``TokenID``
        /// - Throws: if the query fails
        public func balanceOf(queries: [BalanceOfQuery]) async throws -> [TokenAmount] {
            let value = try await self.view(
                entrypoint: EntrypointName(unchecked: "balanceOf"),
                param: Parameter(serializable: BalanceOfQueries(queries: queries))
            )
            let amounts = try value.deserialize(TokenAmounts.self).amounts
            guard queries.count == amounts.count else { throw ListQueryMismatch(queriesCount: UInt(queries.count), responseCount: UInt(amounts.count))}
            return amounts
        }

        /// Query the contract for ``CIS2.TokenMetadata`` corresponding to the ``CIS2.TokenID``
        /// - Parameter tokenID: the token ID to query for
        /// - Throws: if the query fails
        public func tokenMetadata(_ tokenID: TokenID) async throws -> TokenMetadata {
            return try await tokenMetadata(queries: [tokenID])[0]
        }

        /// Query the contract for a list of ``CIS2.TokenMetadata`` corresponding to the list of ``CIS2.TokenID``s
        /// - Parameter queries: the list of token IDs
        /// - Throws: if the query fails
        public func tokenMetadata(queries: [TokenID]) async throws -> [TokenMetadata] {
            let value = try await self.view(
                entrypoint: EntrypointName(unchecked: "tokenMetadat"),
                param: Parameter(serializable: TokenMetadataQuery(ids: queries))
            )
            let metadata = try value.deserialize(TokensMetadata.self).metadata
            guard queries.count == metadata.count else { throw ListQueryMismatch(queriesCount: UInt(queries.count), responseCount: UInt(metadata.count))}
            return metadata
        }

        public func transfer() {}
        //public func transfer() {}
    }
}

extension CIS2.BalanceOfQuery: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        
    }
}

extension CIS2.BalanceOfQueries: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        
    }
}

extension CIS2.TokenAmount: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> CIS2.TokenAmount? {
        
    }
}

extension CIS2.TokenAmounts: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> CIS2.TokenAmounts? {
        
    }
}

extension CIS2.TokenMetadataQuery: Serialize {
    func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        
    }
}

extension CIS2.TokenMetadata: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> CIS2.TokenMetadata? {
        
    }
}

extension CIS2.TokensMetadata: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> CIS2.TokensMetadata? {
        
    }
}