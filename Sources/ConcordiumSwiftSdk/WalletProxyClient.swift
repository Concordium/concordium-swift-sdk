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
    public var arsInfos: [String: AnonymityRevokerInfo]
    public var metadata: Metadata

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
    }

    public func toSdkType() -> IdentityProvider {
        IdentityProvider(
            identity: ipInfo.ipIdentity,
            description: ipInfo.ipDescription,
            verifyKey: ipInfo.ipVerifyKey,
            cdiVerifyKey: ipInfo.ipCdiVerifyKey,
            metadata: metadata
        )
    }
}
