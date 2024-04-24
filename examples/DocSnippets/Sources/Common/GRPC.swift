import Concordium
import GRPC
import NIOPosix

public func withGRPCClient<T>(host: String, port: Int, useTLS: Bool = false, _ f: (GRPCNodeClient) async throws -> T) async throws -> T {
    let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
    defer {
        try! group.syncShutdownGracefully()
    }
    var builder = ClientConnection.insecure(group: group)
    if useTLS {
        // Configure TLS (required for the official gRPC endpoints "grpc.testnet.concordium.com" etc.).
        builder = ClientConnection.usingPlatformAppropriateTLS(for: group)
    }
    let connection = builder.connect(host: host, port: port)
    defer {
        try! connection.close().wait()
    }
    let client = GRPCNodeClient(channel: connection)
    return try await f(client)
}
