import ConcordiumSwiftSDK
import Foundation

import GRPC
import NIO

class ClientManager {
    static let shared = ClientManager()

    private var channel: GRPCChannel?
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private init() {}

    func initialize() throws {
        guard channel == nil else {
            return
        }

        // Run the following command in a terminal to redirect to a node running on a different host/port:
        //   socat TCP-LISTEN:20000,fork TCP:<ip>:<port>
        let channelTarget = ConnectionTarget.host("localhost", port: 20000)

        channel = try GRPCChannelPool.with(
            target: channelTarget,
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
    }

    func getClient() throws -> YourGRPCServiceClient {
        guard let channel = channel else {
            throw GRPCClientError.notInitialized
        }

        return YourGRPCServiceClient(channel: channel)
    }

    func shutdown() throws {
        try group.syncShutdownGracefully()
        try channel?.close().wait()
    }
}

enum GRPCClientError: Error {
    case notInitialized
}
