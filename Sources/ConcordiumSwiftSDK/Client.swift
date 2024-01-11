import Foundation

import GRPC
import NIOPosix
import NIOCore

class Client {
    let grpc: Concordium_V2_QueriesNIOClient

    init(channel: GRPCChannel) {
        grpc = Concordium_V2_QueriesNIOClient(channel: channel)
    }

    private func getBlockHashInput(blockHash: BlockHash?) -> Concordium_V2_BlockHashInput {
        if let blockHash {
            var h = Concordium_V2_BlockHash()
            h.value = blockHash
            var b = Concordium_V2_BlockHashInput()
            b.given = h
            return b
        } else {
            var b = Concordium_V2_BlockHashInput()
            b.lastFinal = Concordium_V2_Empty()
            return b
        }
    }

    func getCryptographicParameters(at block: BlockIdentifier) async -> EventLoopFuture<CryptographicParameters> {
        return grpc
                .getCryptographicParameters(block.toGrpcType())
                .response
                .map({ v in
                    CryptographicParameters(
                            onChainCommitmentKey: v.onChainCommitmentKey.hexadecimalString(),
                            bulletproofGenerators: v.bulletproofGenerators.hexadecimalString(),
                            genesisString: v.genesisString
                    )
                })
    }

    func getNextAccountSequenceNumber(forAddress address: AccountAddress) -> EventLoopFuture<NextAccountSequenceNumber?> {
        var grpcAddress = Concordium_V2_AccountAddress()
        grpcAddress.value = address
        return grpc.getNextAccountSequenceNumber(grpcAddress).response.map({ res in
            NextAccountSequenceNumber(sequenceNumber: SequenceNumber.from(res.sequenceNumber), allFinal: res.allFinal)
        })
    }
}
