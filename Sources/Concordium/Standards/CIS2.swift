import BigInt
import Foundation
import NIO

public struct ListQueryMismatch: Error {
    /// The number of input query parameters
    let queriesCount: UInt
    /// The number of return values in the response
    let responseCount: UInt
}

/// Namespace for any CIS2 related type
public enum CIS2 {
    /// The max length of a token ID
    public static let TOKEN_ID_MAX_LENGTH = 255
    /// The max byte size of a token amount encoding
    public static let TOKEN_AMOUNT_MAX_LENGTH = 37
    /// Represents a token amount of arbitrary precision
    public struct TokenAmount {
        /// The inner amount
        public let amount: BigUInt

        /// Initializes the token amount if the size of the encoding does not exceed ``CIS2.TOKEN_AMOUNT_MAX_LENGTH``
        /// - Parameter amount: the token amount
        public init?(_ amount: BigUInt) {
            guard ULEB128.encode(amount).count <= TOKEN_AMOUNT_MAX_LENGTH else { return nil }
            self.amount = amount
        }
    }

    /// A token ID for a CIS2 contract token
    public struct TokenID {
        let data: Data

        /// Initialize the value, returning `nil` if the data size exceeds ``CIS2.TOKEN_ID_MAX_LENGTH``
        /// - Parameter data:
        public init?(_ data: Data) {
            guard data.count <= TOKEN_ID_MAX_LENGTH else { return nil }
            self.data = data
        }
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

        public init(url: URL, checksum: Data? = nil) {
            self.url = url
            self.checksum = checksum
        }
    }

    /// Data for a ``CIS2.Contract.balanceOf`` query
    public struct BalanceOfQuery {
        /// The token ID to query
        public let tokenId: TokenID
        /// The ``Address`` to query the balance for
        public let address: Address
    }

    /// Describes the possible receivers of a token transfer
    public enum Receiver {
        /// An account receiver
        case account(address: AccountAddress)
        /// A contract receiver, with an associated entrypoint to invoke upon transfer
        case contract(address: ContractAddress, hookName: EntrypointName)
    }

    /// Payload for a CIS2 transfer
    public struct TransferPayload {
        /// The token ID of the token to transfer
        public let tokenID: TokenID
        /// The amount of the token to transfer
        public let amount: TokenAmount
        /// The sender address
        public let sender: Address
        /// The receiver of the tokens
        public let receiver: Receiver
        /// Optional data to include with the transfer
        public let data: Data?
    }

    typealias BalanceOfParam = List<BalanceOfQuery, UInt16>
    typealias TransferParam = List<TransferPayload, UInt16>
    typealias TokenMetadataParam = List<TokenID, UInt16>

    typealias BalanceOfResponse = List<TokenAmount, UInt16>
    typealias TokenMetadataResponse = List<TokenMetadata, UInt16>

    /// Can be used by contracts conforming to the CIS2 standard
    public protocol Client: ContractClient, CIS0.Client {}

    /// Represents an arbitrary CIS2 contract
    public class Contract: GenericContract, CIS0.Client, Client {}
}

public extension CIS2.Client {
    /// Initialize the contract client if the contract supports CIS-2 (queries support through CIS-0 standard)
    /// - Parameters:
    ///   - client: the node client to use
    ///   - address: the contract address
    /// - Throws: if the client cannot look up the contract
    init?(client: NodeClient, address: ContractAddress) async throws {
        let info = try await client.info(contractAddress: address, block: .lastFinal)
        self = .init(client: client, name: info.name, address: address)

        let support = try await supports(CIS0.StandardIdentifier(id: "CIS-2")!)
        switch support {
        case .supported: break
        default: return nil
        }
    }

    /// Query the contract for the balance of an ``Address`` for a specific token
    /// - Parameter queries: the query holding the ``Address`` and ``TokenID``
    /// - Throws: if the query fails
    func balanceOf(_ query: CIS2.BalanceOfQuery) async throws -> CIS2.TokenAmount {
        try await balanceOf(queries: [query])[0]
    }

    /// Query the contract for a list of balances corresponding to a list of ``Address`` for a specific token
    /// - Parameter queries: the list of queries holding the ``Address`` and ``TokenID``
    /// - Throws: if the query fails
    func balanceOf(queries: [CIS2.BalanceOfQuery]) async throws -> [CIS2.TokenAmount] {
        let entrypoint = EntrypointName(unchecked: "balanceOf")
        let param = try Parameter(serializable: CIS2.BalanceOfParam(queries))

        let balances = try await view(entrypoint: entrypoint, param: param).deserialize(CIS2.BalanceOfResponse.self).elements
        guard queries.count == balances.count else { throw ListQueryMismatch(queriesCount: UInt(queries.count), responseCount: UInt(balances.count)) }
        return balances
    }

    /// Query the contract for ``CIS2.TokenMetadata`` corresponding to the ``CIS2.TokenID``
    /// - Parameter tokenID: the token ID to query for
    /// - Throws: if the query fails
    func tokenMetadata(_ tokenID: CIS2.TokenID) async throws -> CIS2.TokenMetadata {
        try await tokenMetadata(queries: [tokenID])[0]
    }

    /// Query the contract for a list of ``CIS2.TokenMetadata`` corresponding to the list of ``CIS2.TokenID``s
    /// - Parameter queries: the list of token IDs
    /// - Throws: if the query fails
    func tokenMetadata(queries: [CIS2.TokenID]) async throws -> [CIS2.TokenMetadata] {
        let entrypoint = EntrypointName(unchecked: "tokenMetadata")
        let param = try Parameter(serializable: CIS2.TokenMetadataParam(queries))

        let metadata = try await view(entrypoint: entrypoint, param: param).deserialize(CIS2.TokenMetadataResponse.self).elements
        guard queries.count == metadata.count else { throw ListQueryMismatch(queriesCount: UInt(queries.count), responseCount: UInt(metadata.count)) }
        return metadata
    }

    /// Construct a ``ContractUpdateProposal`` for a single CIS2 transfers
    /// - Parameter transfers: the transfer payloads
    /// - Throws: if the node client fails to perform the entrypoint invocation
    func transfer(_ transfer: CIS2.TransferPayload) async throws -> ContractUpdateProposal {
        try await self.transfer(transfers: [transfer])
    }

    /// Construct a ``ContractUpdateProposal`` for a list of CIS2 transfers
    /// - Parameter transfers: the list of transfer payloads
    /// - Throws: if the node client fails to perform the entrypoint invocation
    func transfer(transfers: [CIS2.TransferPayload]) async throws -> ContractUpdateProposal {
        let entrypoint = EntrypointName(unchecked: "transfer")
        let param = try Parameter(serializable: CIS2.TransferParam(transfers))
        return try await proposal(entrypoint: entrypoint, param: param)
    }
}

extension CIS2.BalanceOfQuery: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        tokenId.serializeInto(buffer: &buffer) + address.serializeInto(buffer: &buffer)
    }
}

extension CIS2.TokenAmount: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        ULEB128.encode(amount, into: &buffer)
    }
}

extension CIS2.TokenAmount: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> CIS2.TokenAmount? {
        let amount = ULEB128.decode(&data, as: BigUInt.self)
        return CIS2.TokenAmount(amount)
    }
}

extension CIS2.TokenID: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(data, prefixLength: UInt8.self)
    }
}

extension CIS2.TokenMetadata: Deserialize {
    public static func deserialize(_ data: inout Cursor) -> CIS2.TokenMetadata? {
        guard let url = data.readString(prefixLength: UInt16.self).flatMap({ URL(string: $0) }),
              let hasChecksum = data.parseBool() else { return nil }

        if !hasChecksum {
            return CIS2.TokenMetadata(url: url)
        }

        guard let checksum = data.read(num: UInt(32)) else { return nil }
        return CIS2.TokenMetadata(url: url, checksum: checksum)
    }
}

extension CIS2.Receiver: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        switch self {
        case let .account(address):
            buffer.writeInteger(UInt8(0)) + address.serializeInto(buffer: &buffer)
        case let .contract(address, hookName):
            buffer.writeInteger(UInt8(1)) + address.serializeInto(buffer: &buffer) + hookName.serializeInto(buffer: &buffer)
        }
    }
}

extension CIS2.TransferPayload: Serialize {
    public func serializeInto(buffer: inout NIOCore.ByteBuffer) -> Int {
        var written = tokenID.serializeInto(buffer: &buffer) + amount.serializeInto(buffer: &buffer) + sender.serializeInto(buffer: &buffer) + receiver.serializeInto(buffer: &buffer)
        if let data = data {
            written += buffer.writeData(data)
        }
        return written
    }
}