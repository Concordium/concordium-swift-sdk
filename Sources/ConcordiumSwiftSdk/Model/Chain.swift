import ConcordiumWalletCrypto
import Foundation

public struct CryptographicParameters {
    public var onChainCommitmentKey: String
    public var bulletproofGenerators: String
    public var genesisString: String

    static func fromGrpcType(_ grpc: Concordium_V2_CryptographicParameters) -> CryptographicParameters {
        CryptographicParameters(
            onChainCommitmentKey: grpc.onChainCommitmentKey.hex,
            bulletproofGenerators: grpc.bulletproofGenerators.hex,
            genesisString: grpc.genesisString
        )
    }

    public func toCryptoType() -> GlobalContext {
        GlobalContext(
            onChainCommitmentKey: onChainCommitmentKey,
            bulletproofGenerators: bulletproofGenerators,
            genesisString: genesisString
        )
    }
}
