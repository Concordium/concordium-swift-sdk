import ConcordiumWalletCrypto
import Foundation

public typealias CryptographicParameters = ConcordiumWalletCrypto.GlobalContext

extension CryptographicParameters: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_CryptographicParameters) -> Self {
        .init(
            onChainCommitmentKey: grpc.onChainCommitmentKey,
            bulletproofGenerators: grpc.bulletproofGenerators,
            genesisString: grpc.genesisString
        )
    }
}
