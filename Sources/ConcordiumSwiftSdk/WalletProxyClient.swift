import Foundation

public class WalletProxyClient {
    let baseUrl: String

    public init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    public func getIdentityProviderInfo() async throws -> [IdentityProviderInfoJson] {
        let url = URL(string: "\(baseUrl)/v1/ip_info")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([IdentityProviderInfoJson].self, from: data)
    }
}

public struct IdentityProviderInfoJson: Decodable {
    public var ipInfo: IdentityProviderInfo
    public var arsInfos: [UInt32: AnonymityRevokerInfo]
    public var metadata: Metadata

    enum CodingKeys: CodingKey {
        case ipInfo
        case arsInfos
        case metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ipInfo = try container.decode(IdentityProviderInfo.self, forKey: .ipInfo)
        arsInfos = try container.decode([String: AnonymityRevokerInfo].self, forKey: .arsInfos).reduce(into: [:]) { res, e in
            guard let key = UInt32(e.key) else {
                throw DecodingError.dataCorruptedError(forKey: .arsInfos, in: container, debugDescription: "invalid key index")
            }
            res[key] = e.value
        }
        metadata = try container.decode(Metadata.self, forKey: .metadata)
    }

    public struct IdentityProviderInfo: Decodable {
        public var ipIdentity: UInt32
        public var ipDescription: Description
        public var ipCdiVerifyKey: String
        public var ipVerifyKey: String
    }

    public struct AnonymityRevokerInfo: Decodable {
        public var arIdentity: UInt32
        public var arDescription: Description
        public var arPublicKey: String

        public func toSdkType() -> AnonymityRevoker {
            AnonymityRevoker(
                identity: arIdentity,
                description: arDescription,
                publicKey: arPublicKey
            )
        }
    }

    public func toSdkType() -> IdentityProvider {
        IdentityProvider(
            identity: ipInfo.ipIdentity,
            description: ipInfo.ipDescription,
            verifyKey: ipInfo.ipVerifyKey,
            cdiVerifyKey: ipInfo.ipCdiVerifyKey,
            metadata: metadata,
            arsInfos: arsInfos.mapValues { $0.toSdkType() }
        )
    }
}
