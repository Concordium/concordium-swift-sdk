import ConcordiumSwiftSDK
import GRPC
import NIOPosix
import XCTest

// Run the following command in a terminal to redirect to a node running on a different host/port:
//   socat TCP-LISTEN:20000,fork TCP:<ip>:<port>
let channelTarget = ConnectionTarget.host("localhost", port: 20000)

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
defer {
    try! group.syncShutdownGracefully()
}

let channel = try GRPCChannelPool.with(
    target: channelTarget,
    transportSecurity: .plaintext,
    eventLoopGroup: group
)
defer {
    try! channel.close().wait()
}

let client = Client(channel: channel)
let res = try await client.getCryptographicParameters(at: .lastFinal)
print(res)
