@testable import ConcordiumSwiftSDK
import XCTest

import GRPC
import NIOPosix

/// Temporary test for exercising the gRPC client. To run, adjust the channel target to point to a running node.
final class ClientTests: XCTestCase {
    let channelTarget = ConnectionTarget.host("localhost", port: 20000)
    let someBlockHash = "a21c1c18b70c64680a4eceea655ab68d164e8f1c82b8b8566388391d8da81e41"
    let someAccountAddress = "35CJPZohio6Ztii2zy1AYzJKvuxbGG44wrBn7hLHiYLoF2nxnh"

    func testClientGetCryptographicParameters() async throws {
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
        let hash = try BlockHash(fromHexString: someBlockHash)
        let res = try await client.getCryptographicParameters(at: .hash(hash))
        print(res)
    }
    
    func testClientGetNextAccountSequenceNumber() async throws {
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
        let addr = try AccountAddress(base58Check: someAccountAddress)
        let res = try await client.getNextAccountSequenceNumber(of: addr)
        print(res)
    }
}
