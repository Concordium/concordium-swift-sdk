@testable import ConcordiumSwiftSDK
import XCTest

import GRPC
import NIOPosix

/// Temporary test for exercising the gRPC client. To run, adjust the channel target to point to a running node.
final class ClientTests: XCTestCase {
    let channelTarget = ConnectionTarget.host("localhost", port: 20000)
    
    func testClientGetCryptographicParameters() async throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        // Make sure the group is shutdown when we're done with it.
        defer {
          try! group.syncShutdownGracefully()
        }
        let channel = try GRPCChannelPool.with(
            target: channelTarget,
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        // Close the connection when we're done with it.
        defer {
          try! channel.close().wait()
        }
        
        let client = Client(channel: channel)
        let res = await client.getCryptographicParameters(blockHash: try Data(fromHexString: "a21c1c18b70c64680a4eceea655ab68d164e8f1c82b8b8566388391d8da81e41"))
        do {
            print(try await res.get())
        } catch let err {
            print(err)
        }
    }
}
