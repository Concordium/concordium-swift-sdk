import CryptoKit
import Foundation

public struct IdentityRequestInput: Codable {
    let globalContext: CryptographicParameters?
    let arsInfos: [String: AnonymityRevokerInfo]?
    let ipInfo: IdentityProviderInfo?
    private var arThreshold: Int64
    private var idCredSec: String?
    private var prfKey: String?
    private var blindingRandomness: String?
}

struct IdentityProviderInfo: Codable {
    let ipIdentity: UInt32
    let description: Description
    let ipCdiVerifyKey: Curve25519.Signing.PrivateKey
    let ipVerifyKey: Curve25519.Signing.PublicKey

    private enum CodingKeys: String, CodingKey {
        case ipIdentity
        case description
        case ipCdiVerifyKey
        case ipVerifyKey
    }

    // TODO: Do we need to decode at all - isn't it a one-way street?
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ipIdentity = try container.decode(UInt32.self, forKey: .ipIdentity)
        description = try container.decode(Description.self, forKey: .description)

        let ipCdiVerifyKeyData = try container.decode(Data.self, forKey: .ipCdiVerifyKey)
        ipCdiVerifyKey = try Curve25519.Signing.PrivateKey(rawRepresentation: ipCdiVerifyKeyData)

        let ipVerifyKeyData = try container.decode(Data.self, forKey: .ipVerifyKey)
        ipVerifyKey = try Curve25519.Signing.PublicKey(rawRepresentation: ipVerifyKeyData)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ipIdentity, forKey: .ipIdentity)
        try container.encode(description, forKey: .description)

        let ipCdiVerifyKeyData = ipCdiVerifyKey.rawRepresentation
        try container.encode(ipCdiVerifyKeyData, forKey: .ipCdiVerifyKey)

        let ipVerifyKeyData = ipVerifyKey.rawRepresentation
        try container.encode(ipVerifyKeyData, forKey: .ipVerifyKey)
    }
}

public struct AnonymityRevokerInfo: Codable {
    let arIdentity: UInt32
    let arDescription: Description
    let arPublicKey: ElgamalPublicKey
}

public struct Description: Codable {
    let name: String
    let url: String
    let description: String
}
