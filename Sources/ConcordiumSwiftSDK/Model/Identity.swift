import Foundation


public class IdentityRequestInput {
    private var globalContext: CryptographicParameters?
    private var arsInfos: [String: AnonymityRevokerInfo]?
    private var ipInfo: IdentityProviderInfo?
    private var arThreshold: Int64
    private var idCredSec: String?
    private var prfKey: String?
    private var blindingRandomness: String?

    init(globalContext: CryptographicParameters?,
         arsInfos: [String: AnonymityRevokerInfo]?,
         ipInfo: IdentityProviderInfo?,
         arThreshold: Int64,
         idCredSec: String?,
         prfKey: String?,
         blindingRandomness: String?) {
        self.globalContext = globalContext
        self.arsInfos = arsInfos
        self.ipInfo = ipInfo
        self.arThreshold = arThreshold
        self.idCredSec = idCredSec
        self.prfKey = prfKey
        self.blindingRandomness = blindingRandomness
    }
}

struct IdentityProviderInfo: Codable {
    let ipIdentity: UInt32
    let description: Description
    let ipCdiVerifyKey: ED25519PublicKey
    let ipVerifyKey: PSPublicKey
}

public struct AnonymityRevokerInfo: Codable {
    let arIdentity: UInt32
    let arDescription: Description
    let arPublicKey: ElgamalPublicKey
}
