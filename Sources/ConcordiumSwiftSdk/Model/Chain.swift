import Foundation

public struct CryptographicParameters {
    let onChainCommitmentKey: String
    let bulletproofGenerators: String
    let genesisString: String

    static func fromGrpcType(_ grpc: Concordium_V2_CryptographicParameters) -> CryptographicParameters {
        CryptographicParameters(
                onChainCommitmentKey: grpc.onChainCommitmentKey.hexadecimalString(),
                bulletproofGenerators: grpc.bulletproofGenerators.hexadecimalString(),
                genesisString: grpc.genesisString
        )
    }
}
