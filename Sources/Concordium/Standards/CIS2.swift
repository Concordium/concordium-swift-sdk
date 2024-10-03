import Foundation
import BigInt

/// Represent a contract update not yet sent to a node.
public struct ContractUpdateProposal {
    /// The CCD amount to supply to the update (if payable, otherwise 0)
    public let amount: CCD
    /// the contract address of the update
    public let address: ContractAddress
    /// the receive name of the update
    public let receiveName: ReceiveName
    /// The serialized parameter
    public let parameter: Parameter
    /// The node client used to send the transaction
    public var client: NodeClient
    /// The energy to supply to the transaction
    public var energy: Energy
}

public extension ContractUpdateProposal {
    /// Add extra energy to the transaction
    mutating func addEnergy(_ energy: Energy) {
        self.energy += energy
    }

    /// Send the proposal to the node
    /// - Parameters:
    ///   - sender: the sender account
    ///   - signer: the signer for the transaction. This should match the keys for the sender account
    ///   - expiry: An optional expiry. Defaults to 5 minutes in the future.
    /// - Throws: If the client fails to submit the transaction
    /// - Returns: A submitted transaction
    func send(sender: AccountAddress, signer: any Signer, expiry: Date = Date(timeIntervalSinceNow: 5 * 60)) async throws -> SubmittedTransaction {
        let nonce = try await client.nextAccountSequenceNumber(address: sender)
        let transaction = AccountTransaction.updateContract(sender: sender, amount: amount, contractAddress: address, receiveName: receiveName, param: parameter, maxEnergy: energy)
        return try await client.send(transaction: signer.sign(transaction: transaction, sequenceNumber: nonce.sequenceNumber, expiry: UInt64(expiry.timeIntervalSince1970)))
    }
}

/// Protocol for interacting with arbitrary smart contracts.
/// - Example
///   ```
///   public struct SomeContract: CotractClient { // now you have a contract client.
///     public let name: ContractName
///     public let address: ContractAddress
///     public let client: NodeClient
///   }
///   let client = GRPCNodeClient(...)
///   let contract = SomeContract(name: ContractName("test"), address: ContractAddress(index: 3, subindex: 0), client: client)
///   ```
public protocol ContractClient {
    /// The name of the contract
    var name: ContractName { get }
    /// The contract address used to query
    var address: ContractAddress { get }
    /// The node client used to query the contract at `address`
    var client: NodeClient { get }
}

/// Describes errors happening while invoking contract client methods.
public enum ContractClientError: Error {
    /// The return value could not be deserialized.
    case noReturnValue
}

extension ContractClient {
    /// Invoke a contract view entrypoint
    /// - Parameters:
    ///   - entrypoint: the entrypoint to invoke
    ///   - query: the query to invoke the entrypoint with
    ///   - block: the block to invoke the entrypoint at. Defaults to `.lastFinal`
    /// - Throws: If the query cannot be serialized, if node client request fails, or if the response is nil or cannot be deserialized.
    /// - Returns: The deserialized query response
    public func view<Q: Serialize, R: Deserialize>(entrypoint: EntrypointName, query: Q, block: BlockIdentifier = .lastFinal) async throws -> R {
        var request = ContractInvokeRequest(contract: address, method: try ReceiveName(contractName: name, entrypoint: entrypoint))
        request.parameter = try Parameter(query.serialize())
        let res = try await client.invokeInstance(request: request, block: block).success()
        guard let response = res.returnValue else { throw ContractClientError.noReturnValue }
        return try R.deserialize(response)
    }

    /// Construct a ``ContractUpdateProposal`` by invoking the contract entrypoint. The proposal can then subsequently be signed and submitted to the node.
    /// - Parameters:
    ///   - entrypoint: the entrypoint to invoke
    ///   - query: the query to invoke the entrypoint with
    ///   - amount: An optional ``CCD`` amount to add to the query, if it is payable. Defaults to 0 CCD.
    /// - Throws: If the query cannot be serialized, if node client request fails.
    /// - Returns: A corresponding ``ContractUpdateProposal`` which can be signed and submitted.
    public func proposal<Q: Serialize>(entrypoint: EntrypointName, query: Q, amount: CCD = CCD(microCCD: 0)) async throws -> ContractUpdateProposal {
        var request = ContractInvokeRequest(contract: address, method: try ReceiveName(contractName: name, entrypoint: entrypoint))
        request.parameter = try Parameter(query.serialize())
        let res = try await client.invokeInstance(request: request, block: .lastFinal).success()
        return ContractUpdateProposal(amount: amount, address: address, receiveName: request.method, parameter: request.parameter, client: client, energy: res.usedEnergy)
    }
}

/// Namespace for any CIS2 related type
public struct CIS2 {
    /// Represents a token amount of arbitrary precision
    public struct TokenAmount {
        /// The inner amount
        public let amount: BigUInt
    }

    /// A token ID for a CIS2 contract token
    public typealias TokenID = Data

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

    /// Data for a ``CIS2.Contract.balanceOf`` query
    public struct BalanceOfQuery {
        /// The token ID to query
        public let tokenId: Data
        /// The ``Address`` to query the balance for
        public let address: Address
    }

    /// Represents an arbitrary CIS2 contract
    public struct Contract: ContractClient {
        public let name: ContractName
        public let address: ContractAddress
        public let client: NodeClient

        public init(client: NodeClient, name: ContractName, address: ContractAddress) {
            self.client = client
            self.name = name
            self.address = address
        }

        public func balanceOf(_ query: BalanceOfQuery) -> TokenAmount {}
        public func balanceOf(queries: [BalanceOfQuery]) -> [TokenAmount] {}

        public func tokenMetadata() -> TokenMetadata {}
        public func tokenMetadata() -> [TokenMetadata] {}

        public func transfer() {}
        // public func transfer() {}
    }
}

