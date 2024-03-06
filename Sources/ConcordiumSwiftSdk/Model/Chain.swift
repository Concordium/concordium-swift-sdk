import ConcordiumWalletCrypto
import Foundation

public typealias CryptographicParameters = ConcordiumWalletCrypto.GlobalContext

extension CryptographicParameters {
    static func fromGrpcType(_ grpc: Concordium_V2_CryptographicParameters) -> Self {
        .init(
            onChainCommitmentKey: grpc.onChainCommitmentKey.hex,
            bulletproofGenerators: grpc.bulletproofGenerators.hex,
            genesisString: grpc.genesisString
        )
    }
}
