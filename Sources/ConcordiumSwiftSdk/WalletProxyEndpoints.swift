import Foundation

public enum WalletProxyEndpointError: Error {
    case cannotConstructUrl
}

public class WalletProxyEndpoints {
    let baseUrl: URL

    public init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }

    public var getIdentityProviders: HttpRequest<[IdentityProviderJson]> {
        get throws {
            try HttpRequest(url: URL(string: "/v1/ip_info", relativeTo: baseUrl) ?! WalletProxyEndpointError.cannotConstructUrl)
        }
    }
}

public struct IdentityProviderJson: Decodable {
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

        public func toSdkType() -> ConcordiumSwiftSdk.IdentityProviderInfo {
            .init(
                identity: ipIdentity,
                description: ipDescription,
                verifyKeyHex: ipVerifyKey,
                cdiVerifyKeyHex: ipCdiVerifyKey
            )
        }
    }

    public struct AnonymityRevokerInfo: Decodable {
        public var arIdentity: UInt32
        public var arDescription: Description
        public var arPublicKey: String

        public func toSdkType() -> ConcordiumSwiftSdk.AnonymityRevokerInfo {
            .init(
                identity: arIdentity,
                description: arDescription,
                publicKeyHex: arPublicKey
            )
        }
    }

    public func toSdkType() -> IdentityProvider {
        .init(
            info: ipInfo.toSdkType(),
            metadata: metadata,
            anonymityRevokers: arsInfos.mapValues { $0.toSdkType() }
        )
    }
}
