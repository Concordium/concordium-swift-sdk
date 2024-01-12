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
        let req = block.toGrpcType()
        let res = try await grpc.getCryptographicParameters(req).response.get()
        return CryptographicParameters(
                onChainCommitmentKey: res.onChainCommitmentKey.hexadecimalString(),
                bulletproofGenerators: res.bulletproofGenerators.hexadecimalString(),
                genesisString: res.genesisString
        )
    }

    func getNextAccountSequenceNumber(of address: AccountAddress) async throws -> NextAccountSequenceNumber {
        var req = Concordium_V2_AccountAddress()
        req.value = address.bytes
        let res = try await grpc.getNextAccountSequenceNumber(req).response.get()
        return NextAccountSequenceNumber(
                sequenceNumber: res.sequenceNumber.value,
                allFinal: res.allFinal
        )
    }

    func getAccountInfo(of account: AccountIdentifier, at block: BlockIdentifier) async throws -> AccountInfo {
        var req = Concordium_V2_AccountInfoRequest()
        req.accountIdentifier = account.toGrpcType()
        req.blockHash = block.toGrpcType()
        let res = try await grpc.getAccountInfo(req).response.get()
        return AccountInfo(
            accountNonce: res.sequenceNumber.value,
            accountAmount: res.amount.value,
            accountReleaseSchedule: AccountReleaseSchedule.fromGrpcType(res.schedule),
            accountCredentials: try res.creds.mapValues {
                Versioned<AccountCredentialWithoutProofs<ArCurve, AttributeKind>>(
                    version: 0, // same as in Rust SDK
                    value: try .fromGrpcType($0)
                )
            },
            accountThreshold: res.threshold.value,
            accountEncryptedAmount: AccountEncryptedAmount.fromGrpcType(res.encryptedBalance),
            accountEncryptionKey: res.encryptionKey.value,
            accountIndex: res.index.value,
            accountStake: try .fromGrpcType(res.stake),
            accountAddress: AccountAddress(res.address.value)
        )
    }
}
