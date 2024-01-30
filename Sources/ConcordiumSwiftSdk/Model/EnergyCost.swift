import Foundation

/// These constants must be consistent with constA and constB in:
/// https://github.com/Concordium/concordium-base/blob/main/haskell-src/Concordium/Cost.hs
let constantA: BigInt = 100
let constantB: BigInt = 1

/// Account address (32 bytes), nonce (8 bytes), energy (8 bytes), payload size (4 bytes), expiry (8 bytes);
let accountTransactionHeaderSize = BigInt(32 + 8 + 8 + 4 + 8)

/// Calculates the energy cost for a transaction.
///
/// The energy cost is determined by the formula: A * signatureCount + B * size + C_t,
/// where A and B are constants, and C_t is a transaction-specific cost.
///
/// - Parameters:
///   - signatureCount: Number of signatures for the transaction.
///   - payloadSize: Size of the payload in bytes.
///   - transactionSpecificCost: A transaction-specific cost.
///
/// - Returns: The energy cost for the transaction.
func calculateEnergyCost(
        signatureCount: BigInt,
        payloadSize: BigInt,
        transactionSpecificCost: BigInt
) -> UInt64 {
    constantA * signatureCount +
            constantB * (accountTransactionHeaderSize + payloadSize) +
            transactionSpecificCost
}