@testable import ConcordiumSwiftSDK
import GRPC
import NIOPosix
import XCTest

/// Temporary test for exercising the gRPC client. Note that there are no assertions on the result; it's only printed for manual inspection.
///
/// To run one or more tests, adjust the channel target static field to point to a running node.
/// Alternatively, run the following command in a terminal to make the OS automatically
/// forward requests for localhost:20000 to [IP]:[port]:
///
///     socat TCP-LISTEN:20000,fork TCP:[IP]:[port]
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
