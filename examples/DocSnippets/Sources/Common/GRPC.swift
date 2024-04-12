import Concordium
import Foundation
import GRPC
import NIOPosix

func withGRPCClient<T>(target: ConnectionTarget, _ f: (GRPCNodeClient) async throws -> T) async throws -> T {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer {
        try! group.syncShutdownGracefully()
    }
    let channel = try GRPCChannelPool.with(
        target: target,
        transportSecurity: .plaintext,
        eventLoopGroup: group
    )
    defer {
        try! channel.close().wait()
    }
    let client = GRPCNodeClient(channel: channel)
    return try await f(client)
}
