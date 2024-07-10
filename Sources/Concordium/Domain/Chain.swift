import ConcordiumWalletCrypto
import Foundation

public typealias CryptographicParameters = ConcordiumWalletCrypto.GlobalContext

extension CryptographicParameters: FromGRPC {
    static func fromGRPC(_ grpc: Concordium_V2_CryptographicParameters) -> Self {
        .init(
            onChainCommitmentKeyHex: grpc.onChainCommitmentKey.hex,
            bulletproofGeneratorsHex: grpc.bulletproofGenerators.hex,
            genesisString: grpc.genesisString
        )
    }
}
