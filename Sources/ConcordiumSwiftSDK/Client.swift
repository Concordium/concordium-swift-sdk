import Foundation
import GRPC
import NIOCore
import NIOPosix

public class Client {
    let grpc: Concordium_V2_QueriesClientProtocol

    init(_ grpc: Concordium_V2_QueriesClientProtocol) {
        self.grpc = grpc
    }

    public convenience init(channel: GRPCChannel) {
        self.init(Concordium_V2_QueriesNIOClient(channel: channel))
    }

    public func getCryptographicParameters(at block: BlockIdentifier) async throws -> CryptographicParameters {
        let req = block.toGrpcType()
        let res = try await grpc.getCryptographicParameters(req).response.get()
        return CryptographicParameters(
            onChainCommitmentKey: res.onChainCommitmentKey.hexadecimalString(),
            bulletproofGenerators: res.bulletproofGenerators.hexadecimalString(),
            genesisString: res.genesisString
        )
    }

    public func getNextAccountSequenceNumber(of address: AccountAddress) async throws -> NextAccountSequenceNumber {
        var req = Concordium_V2_AccountAddress()
        req.value = address.bytes
        let res = try await grpc.getNextAccountSequenceNumber(req).response.get()
        return NextAccountSequenceNumber(
            sequenceNumber: res.hasSequenceNumber ? res.sequenceNumber.value : nil,
            allFinal: res.allFinal
        )
    }

    public func getAccountInfo(of account: AccountIdentifier, at block: BlockIdentifier) async throws -> AccountInfo {
        var req = Concordium_V2_AccountInfoRequest()
        req.accountIdentifier = account.toGrpcType()
        req.blockHash = block.toGrpcType()
        let res = try await grpc.getAccountInfo(req).response.get()
        return try .fromGrpcType(res)
    }
}
