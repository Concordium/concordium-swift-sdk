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
    public struct TokenAmount: Equatable {
        /// The inner amount
        public let amount: BigUInt

        /// Initializes the token amount if the size of the encoding does not exceed ``CIS2.TOKEN_AMOUNT_MAX_LENGTH``
        /// - Parameter amount: the token amount
        public init?(_ amount: BigUInt) {
            guard ULEB128.encode(amount).count <= TOKEN_AMOUNT_MAX_LENGTH else { return nil }
            self.amount = amount
        }

        public init?(_ amount: any UnsignedInteger) {
            guard let amount = Self(BigUInt(amount)) else { return nil }
            self = amount
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

        /// Initialize an empty TokenID.
        public init() {
            self.data = Data()
        }

        /// Initialize from any integer
        public init?<I: FixedWidthInteger>(int: I, as _: I.Type = I.self) {
            var buf = ByteBuffer()
            buf.writeInteger(int, endianness: .little)
            guard let id = Self(Data(buffer: buf)) else { return nil }
            self = id
        }

        /// Initialize from a hex string
        /// - Throws: if the string is not valid hex
        public init?(hex: String) throws {
            guard let id = try Self(Data(hex: hex)) else { return nil }
            self = id
        }
    }

    /// Represents a token address, i.e. a contract + token ID
    public struct TokenAddress {
        /// The contract address holding the token
        public let contract: ContractAddress
        /// The token ID within the associated contract
        public let id: TokenID

        public init(id: TokenID, contract: ContractAddress) {
            self.id = id
            self.contract = contract
        }
    }

    /// Represents a token metadata URL for a CIS2 token
    public struct TokenMetadataUrl: Equatable {
        /// The url
        public let url: URL
        /// An optional SHA256 checksum for the data at the `url`
        public let checksum: Data?

        public init(url: URL, checksum: Data? = nil) {
            self.url = url
            self.checksum = checksum
        }
    }

    /// The token metadata is stored off-chain and is expected be a JSON (RFC 8259) file.
    /// All of the fields in the JSON file are optional, and this specification reserves a number of field names, shown in the table below.
    public struct TokenMetadata: Codable {
        /// The name to display for the token type.
        public var name: String?
        /// Short text to display for the token type.
        public var symbol: String?
        /// Describes whether a token should be treated as unique.
        /// If unique, a wallet should treat the balance as a boolean.
        /// If this field is not present, the token should not be treated as unique.
        public var unique: Bool?
        /// The number of decimals, when displaying an amount of this token type in a user interface.
        /// If the decimal is set to d then a token amount a should be displayed as `a * 10^(-d)`
        public var decimals: UInt8
        /// A description for this token type.
        public var description: String?
        /// An image URL to a small image for displaying the asset.
        public var thumbnail: TokenMetadata.Url?
        /// An image URL to a large image for displaying the asset.
        public var display: TokenMetadata.Url?
        /// A URL to the token asset.
        public var artifact: TokenMetadata.Url?
        /// Collection of assets.
        public var assets: [TokenMetadata]?
        /// Assign a number of attributes to the token type. Attributes can be used to include extra information about the token type.
        public var attributes: [Attribute]?
        /// URLs to JSON files with localized token metadata.
        public var localization: [Locale: Url]?

        public struct Url: Codable {
            /// A URL.
            public var url: URL
            /// A SHA256 hash of the `url` content encoded as a hex string.
            public var hash: Data?
        }

        public struct Attribute: Codable {
            /// Type for the value field of the attribute.
            public var type: String
            /// Name of the attribute.
            public var name: String
            /// Value of the attrbute.
            public var value: String
        }
    }

    /// Data for a ``CIS2.Contract.balanceOf`` query
    public struct BalanceOfQuery {
        /// The token ID to query
        public let tokenId: TokenID
        /// The ``Address`` to query the balance for
        public let address: Address

        public init(tokenId: TokenID, address: Address) {
            self.tokenId = tokenId
            self.address = address
        }

        /// Convenience for getting the balance for an account
        public init(tokenId: TokenID, address: AccountAddress) {
            self = .init(tokenId: tokenId, address: Address.account(address))
        }
    }

    /// Describes the possible receivers of a token transfer
    public enum Receiver {
        /// An account receiver
        case account(_ address: AccountAddress)
        /// A contract receiver, with an associated entrypoint to invoke upon transfer
        case contract(_ address: ContractAddress, hookName: ReceiveName)
    }

    /// Payload for a CIS2 transfer
    public struct TransferPayload {
        /// The token ID of the token to transfer
        public let tokenId: TokenID
        /// The amount of the token to transfer
        public let amount: TokenAmount
        /// The sender address
        public let sender: Address
        /// The receiver of the tokens
        public let receiver: Receiver
        /// Optional data to include with the transfer
        public let data: Data?

        public init(tokenId: TokenID, amount: TokenAmount, sender: Address, receiver: Receiver, data: Data? = nil) {
            self.tokenId = tokenId
            self.amount = amount
            self.sender = sender
            self.receiver = receiver
            self.data = data
        }

        /// Convenience for describing a transfer between two accounts
        public init(tokenId: TokenID, amount: TokenAmount, sender: AccountAddress, receiver: AccountAddress, data: Data? = nil) {
            self = .init(tokenId: tokenId, amount: amount, sender: Address.account(sender), receiver: CIS2.Receiver.account(receiver), data: data)
        }
    }

    typealias BalanceOfParam = PrefixListLE<BalanceOfQuery, UInt16>
    typealias TransferParam = PrefixListLE<TransferPayload, UInt16>
    typealias TokenMetadataParam = PrefixListLE<TokenID, UInt16>

    typealias BalanceOfResponse = PrefixListLE<TokenAmount, UInt16>
    typealias TokenMetadataResponse = PrefixListLE<TokenMetadataUrl, UInt16>

    /// Can be used by contracts conforming to the CIS2 standard
    public protocol Client: ContractClient, CIS0.Client {}

    /// Represents an arbitrary CIS2 contract
    public class Contract: GenericContract, CIS0.Client, Client {}
}

public extension CIS2.TokenMetadataUrl {
    /// Get, parse, and check (if checksum is specified) the data at the URL.
    /// - Throws:
    ///   - if the http request fails
    ///   - if the data cannot be parsed
    ///   - if verification of the data fails (checksum)
    func get() async throws -> CIS2.TokenMetadata {
        let req = HTTPRequest<CIS2.TokenMetadata>(url: url)
        if let checksum = checksum {
            return try await req.send(checkSHA256: checksum)
        }
        return try await req.send()
    }
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
    func tokenMetadata(_ tokenID: CIS2.TokenID) async throws -> CIS2.TokenMetadataUrl {
        try await tokenMetadata(queries: [tokenID])[0]
    }

    /// Query the contract for a list of ``CIS2.TokenMetadata`` corresponding to the list of ``CIS2.TokenID``s
    /// - Parameter queries: the list of token IDs
    /// - Throws: if the query fails
    func tokenMetadata(queries: [CIS2.TokenID]) async throws -> [CIS2.TokenMetadataUrl] {
        let entrypoint = EntrypointName(unchecked: "tokenMetadata")
        let param = try Parameter(serializable: CIS2.TokenMetadataParam(queries))

        let metadata = try await view(entrypoint: entrypoint, param: param).deserialize(CIS2.TokenMetadataResponse.self).elements
        guard queries.count == metadata.count else { throw ListQueryMismatch(queriesCount: UInt(queries.count), responseCount: UInt(metadata.count)) }
        return metadata
    }

    /// Construct a ``ContractUpdateProposal`` for a single CIS2 transfers
    /// - Parameter transfers: the transfer payloads
    /// - Parameter sender: the sending account
    /// - Throws: if the node client fails to perform the entrypoint invocation
    func transfer(_ transfer: CIS2.TransferPayload, sender: AccountAddress) async throws -> ContractUpdateProposal {
        try await self.transfer(transfers: [transfer], sender: sender)
    }

    /// Construct a ``ContractUpdateProposal`` for a list of CIS2 transfers
    /// - Parameter transfers: the list of transfer payloads
    /// - Parameter sender: the sending account
    /// - Throws: if the node client fails to perform the entrypoint invocation
    func transfer(transfers: [CIS2.TransferPayload], sender: AccountAddress) async throws -> ContractUpdateProposal {
        let entrypoint = EntrypointName(unchecked: "transfer")
        let param = try Parameter(serializable: CIS2.TransferParam(transfers))
        return try await proposal(entrypoint: entrypoint, param: param, sender: sender)
    }
}

extension CIS2.TokenID: ContractSerialize {
    public func contractSerialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        buffer.writeData(data, prefix: LengthPrefix<UInt8>())
    }
}

extension CIS2.BalanceOfQuery: ContractSerialize {
    public func contractSerialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        tokenId.contractSerialize(into: &buffer) + address.contractSerialize(into: &buffer)
    }
}

extension CIS2.TokenAmount: ContractSerialize {
    public func contractSerialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        ULEB128.encode(amount, into: &buffer)
    }
}

extension CIS2.TokenAmount: ContractDeserialize {
    public static func contractDeserialize(_ data: inout Cursor) -> CIS2.TokenAmount? {
        let amount = ULEB128.decode(&data, as: BigUInt.self)
        return CIS2.TokenAmount(amount)
    }
}

extension CIS2.TokenMetadataUrl: ContractDeserialize {
    public static func contractDeserialize(_ data: inout Cursor) -> CIS2.TokenMetadataUrl? {
        guard let url = data.readString(prefix: LengthPrefix.LE(size: UInt16.self)).flatMap({ URL(string: $0) }),
              let hasChecksum = data.parseBool() else { return nil }

        if !hasChecksum {
            return CIS2.TokenMetadataUrl(url: url)
        }

        guard let checksum = data.read(num: UInt(32)) else { return nil }
        return CIS2.TokenMetadataUrl(url: url, checksum: checksum)
    }
}

extension CIS2.Receiver: ContractSerialize {
    public func contractSerialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        switch self {
        case let .account(address):
            buffer.writeInteger(UInt8(0)) + address.serialize(into: &buffer)
        case let .contract(address, hookName):
            buffer.writeInteger(UInt8(1)) + address.contractSerialize(into: &buffer) + hookName.contractSerialize(into: &buffer)
        }
    }
}

extension CIS2.TransferPayload: ContractSerialize {
    public func contractSerialize(into buffer: inout NIOCore.ByteBuffer) -> Int {
        tokenId.contractSerialize(into: &buffer)
            + amount.contractSerialize(into: &buffer)
            + sender.contractSerialize(into: &buffer)
            + receiver.contractSerialize(into: &buffer)
            + buffer.writeData(data ?? Data([]), prefix: LengthPrefix.LE(size: UInt16.self))
    }
}
