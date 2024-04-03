import ConcordiumWalletCrypto
import Foundation
import NIO

/// Transaction time specified as seconds since unix epoch.
public typealias TransactionTime = UInt64

public typealias Signatures = [CredentialIndex: CredentialSignatures]
public typealias CredentialSignatures = [KeyIndex: Data]

public extension AccountCredential {
    func prepareDeployment(expiry: TransactionTime) -> PreparedAccountCredentialDeployment {
        .init(credential: self, expiry: expiry)
    }
}

public struct PreparedAccountCredentialDeployment {
    public var credential: AccountCredential
    public var expiry: TransactionTime

    public var hash: Data {
        get throws {
            let hex = try accountCredentialDeploymentHashHex(
                credential: credential,
                expiryUnixSecs: expiry
            )
            return try Data(hex: hex)
        }
    }
}

public struct SignedAccountCredentialDeployment {
    public var deployment: PreparedAccountCredentialDeployment
    public var signatures: CredentialSignatures

    public init(deployment: PreparedAccountCredentialDeployment, signatures: CredentialSignatures) {
        self.deployment = deployment
        self.signatures = signatures
    }

    public func toCryptoType() -> SignedAccountCredential {
        .init(
            credential: deployment.credential,
            signaturesHex: signatures.mapValues { $0.hex }
        )
    }

    public func serialize() throws -> SerializedSignedAccountCredentialDeployment {
        let hex = try accountCredentialDeploymentSignedPayloadHex(credential: toCryptoType())
        return try .init(data: Data(hex: hex), expiry: deployment.expiry)
    }
}

public struct SerializedSignedAccountCredentialDeployment {
    public var data: Data
    public var expiry: TransactionTime

    public init(data: Data, expiry: TransactionTime) {
        self.data = data
        self.expiry = expiry
    }

    func toGRPCType() -> Concordium_V2_CredentialDeployment {
        var x = Concordium_V2_TransactionTime()
        x.value = expiry
        var d = Concordium_V2_CredentialDeployment()
        d.messageExpiry = x
        d.rawPayload = data
        return d
    }
}
