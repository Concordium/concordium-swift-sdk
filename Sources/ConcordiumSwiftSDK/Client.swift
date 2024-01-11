import Foundation

import GRPC
import NIOCore
import NIOPosix

class Client {
    let grpc: Concordium_V2_QueriesNIOClient

    init(channel: GRPCChannel) {
        grpc = Concordium_V2_QueriesNIOClient(channel: channel)
    }

    func getCryptographicParameters(at block: BlockIdentifier) async throws -> CryptographicParameters {
        var req = block.toGrpcType()
        let res = try await grpc.getCryptographicParameters(req).response.get()
        return CryptographicParameters(
                onChainCommitmentKey: res.onChainCommitmentKey.hexadecimalString(),
                bulletproofGenerators: res.bulletproofGenerators.hexadecimalString(),
                genesisString: res.genesisString
        )
    }

    func getNextAccountSequenceNumber(of address: AccountAddress) async throws -> NextAccountSequenceNumber {
        var req = Concordium_V2_AccountAddress()
        req.value = address
        let res = try await grpc.getNextAccountSequenceNumber(req).response.get()
        return NextAccountSequenceNumber(
                sequenceNumber: res.sequenceNumber.value,
                allFinal: res.allFinal
        )
    }
}
