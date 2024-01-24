import Foundation

public struct CryptographicParameters: Codable {
    let onChainCommitmentKey: String
    let bulletproofGenerators: String
    let genesisString: String
}
