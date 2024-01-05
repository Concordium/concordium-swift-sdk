import Foundation

import GRPC
import NIOPosix
import NIOCore

typealias BlockHash = Data

struct CryptographicParameters {
    let onChainCommitmentKey: String
    let bulletproofGenerators: String
    let genesisString: String
}

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
    
    func getCryptographicParameters(blockHash: BlockHash?) async -> EventLoopFuture<CryptographicParameters> {
        let bh = getBlockHashInput(blockHash: blockHash)
        print(bh)
        let res = grpc.getCryptographicParameters(bh)
        return res.response.map({v in
            CryptographicParameters(
                onChainCommitmentKey: v.onChainCommitmentKey.hexadecimalString(),
                bulletproofGenerators: v.bulletproofGenerators.hexadecimalString(),
                genesisString: v.genesisString)
        })
    }
}
