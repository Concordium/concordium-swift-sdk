import Concordium
import Foundation
import GRPC
import NIOCore
import NIOPosix

class DisposableNodeClient {
    private let group: EventLoopGroup
    private let channel: GRPCChannel
    let client: GRPCNodeClient

    init(target: ConnectionTarget) throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        channel = try GRPCChannelPool.with(
            target: target,
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        client = GRPCNodeClient(channel: channel)
    }

    deinit {
        try! group.syncShutdownGracefully()
        try! channel.close().wait()
    }
}
