import ArgumentParser
import Concordium
import Foundation
import GRPC
import NIOPosix

struct GRPCOptions: ParsableArguments {
    @Option(help: "IP or DNS name of the Node.")
    var host = "localhost"

    @Option(help: "Port of the Node.")
    var port = 20000

    var target: ConnectionTarget {
        ConnectionTarget.host(host, port: port)
    }
}

struct BlockOption: ParsableArguments {
    @Option(help: "Hash of the block to query against. Defaults to last finalized block.")
    var blockHash: String?

    var block: BlockIdentifier {
        get throws {
            if let blockHash {
                return try .hash(BlockHash(hex: blockHash))
            }
            return .lastFinal
        }
    }
}

struct AccountOption: ParsableArguments {
    @Argument(help: "Address of the account to inspect.")
    var accountAddress: String

    var address: AccountAddress {
        get throws {
            try AccountAddress(base58Check: accountAddress)
        }
    }

    var identifier: AccountIdentifier {
        get throws {
            try .address(address)
        }
    }
}

@main
struct Root: AsyncParsableCommand {
    @OptionGroup
    var options: GRPCOptions

    static var configuration = CommandConfiguration(
        abstract: "A CLI for demonstrating and testing use of the gRPC client of the SDK.",
        version: "1.0.0",
        subcommands: [CryptographicParameters.self, Account.self]
    )

    struct CryptographicParameters: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the cryptographic parameters of the chain."
        )

        @OptionGroup
        var root: Root

        @OptionGroup
        var block: BlockOption

        func run() async throws {
            let res = try await withGRPCClient(target: root.options.target) {
                try await $0.cryptographicParameters(
                    block: block.block
                )
            }
            print(res)
        }
    }

    struct Account: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Subcommands related to a particular account.",
            subcommands: [NextSequenceNumber.self, Info.self]
        )

        @OptionGroup
        var account: AccountOption

        struct NextSequenceNumber: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Display the next sequence number of the provided account."
            )

            @OptionGroup
            var root: Root

            @OptionGroup
            var accountCmd: Account

            func run() async throws {
                let res = try await withGRPCClient(target: root.options.target) {
                    try await $0.nextAccountSequenceNumber(
                        address: accountCmd.account.address
                    )
                }
                print(res)
            }
        }

        struct Info: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Display info of the provided account."
            )

            @OptionGroup
            var root: Root

            @OptionGroup
            var block: BlockOption

            @OptionGroup
            var accountCmd: Account

            func run() async throws {
                let res = try await withGRPCClient(target: root.options.target) {
                    try await $0.info(
                        account: accountCmd.account.identifier,
                        block: block.block
                    )
                }
                print(res)
            }
        }
    }
}

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
