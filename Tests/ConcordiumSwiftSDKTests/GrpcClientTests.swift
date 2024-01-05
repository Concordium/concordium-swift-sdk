@testable import ConcordiumSwiftSDK
import XCTest

import GRPC
import NIOPosix

/// Temporary test for exercising the gRPC client. To run, adjust the channel target to point to a running node.
final class GrpcClientTests: XCTestCase {
    let channelTarget = ConnectionTarget.host("localhost", port: 20000)
    
    func testExampleClientConsensusStatus() throws {
        // Setup an `EventLoopGroup` for the connection to run on.
        //
        // See: https://github.com/apple/swift-nio#eventloops-and-eventloopgroups
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
        let client = Concordium_V2_QueriesNIOClient(channel: channel)
        
        let req = Concordium_V2_Empty()
        let res = client.getNodeInfo(req)
        let info = try res.response.wait()
        print(info)
        XCTAssertNotNil(info)
    }
}
