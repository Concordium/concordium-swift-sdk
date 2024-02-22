import ArgumentParser
import ConcordiumSwiftSdk
import Foundation
import GRPC
import MnemonicSwift
import NIOPosix

struct GrpcOptions: ParsableArguments {
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
    @Argument(help: "Address of the account to interact with.")
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
struct GrpcCli: AsyncParsableCommand {
    @OptionGroup
    var options: GrpcOptions

    static var configuration = CommandConfiguration(
        abstract: "A CLI for demonstrating and testing use of the gRPC client of the SDK.",
        version: "1.0.0",
        subcommands: [CryptographicParameters.self, Account.self, Wallet.self, LegacyWallet.self]
    )

    struct CryptographicParameters: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the cryptographic parameters of the chain."
        )

        @OptionGroup
        var grpcCli: GrpcCli

        @OptionGroup
        var block: BlockOption

        func run() async throws {
            let res = try await withClient(target: grpcCli.options.target) {
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
            var grpcCli: GrpcCli

            @OptionGroup
            var accountCli: Account

            func run() async throws {
                let res = try await withClient(target: grpcCli.options.target) {
                    try await $0.nextAccountSequenceNumber(
                        address: accountCli.account.address
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
            var grpcCli: GrpcCli

            @OptionGroup
            var block: BlockOption

            @OptionGroup
            var accountCli: Account

            func run() async throws {
                let res = try await withClient(target: grpcCli.options.target) {
                    try await $0.info(
                        account: accountCli.account.identifier,
                        block: block.block
                    )
                }
                print(res)
            }
        }
    }

    struct Wallet: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Subcommands related to wallet activities.",
            subcommands: [Transfer.self]
        )

        @Option(help: "Seed phrase")
        var seedPhrase: String

        @Option(help: "Index of IP that issued identity")
        var identityProviderIndex: UInt32

        @Option(help: "Index of identity issued by IP")
        var identityIndex: UInt32

        @Option(help: "Index of credential derived from identity used to generate the account")
        var credentialCounter: UInt8

        @Option(help: "Commitment key for the given network")
        var commitmentKey: String

        struct Transfer: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CCDs to another account."
            )

            @OptionGroup
            var grpcCli: GrpcCli

            @OptionGroup
            var walletCli: Wallet

            @OptionGroup
            var receiver: AccountOption

            @Option(help: "Amount of uCCD to send")
            var amount: MicroCcdAmount

            @Option(help: "Timestamp in Unix time of transaction expiry")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                // Derive account and put it into wallet.
                let seedHex = try Mnemonic.deterministicSeedString(from: walletCli.seedPhrase)
                print("Resolved seed hex '\(seedHex)'.")
                let seed = WalletSeed(hex: seedHex, network: .testnet)
                let gen = SeedBasedAccountGenerator(seed: seed, commitmentKey: walletCli.commitmentKey)
                let account = try gen.generateAccount(
                    credentials: [
                        AccountCredential(
                            identity: Identity(providerIndex: walletCli.identityProviderIndex, index: walletCli.identityIndex),
                            counter: walletCli.credentialCounter
                        ),
                    ]
                )
                let wallet = SimpleWallet()
                wallet.insert(account: account)

                print("Resolved address \(account.address.base58Check) from credential \(walletCli.credentialCounter) of identity \(walletCli.identityProviderIndex):\(walletCli.identityIndex).")
                print("Attempting to send \(amount) uCCD from account '\(account.address.base58Check)' to '\(receiver.accountAddress)'.")

                // Construct and send transaction.
                let hash = try await withClient(target: grpcCli.options.target) { client in
                    print("Resolving next sequence number of sender account.")
                    let next = try await client.nextAccountSequenceNumber(address: account.address)
                    print("Preparing transaction.")
                    let tx = try AccountTransaction(
                        sender: account.address,
                        payload: .transfer(amount: amount, receiver: receiver.address)
                    ).prepare(
                        sequenceNumber: next.sequenceNumber,
                        expiry: expiry,
                        signatureCount: account.keys.count
                    )
                    print("Signing transaction.")
                    let stx = try wallet.sign(transaction: tx)
                    print("Sending transaction.")
                    return try await client.send(transaction: stx)
                }
                print("Transaction with hash '\(hash.hex)' successfully submitted.")
            }
        }
    }

    struct LegacyWallet: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Subcommands related to legacy wallet activities.",
            subcommands: [Transfer.self]
        )

        @Option
        var exportFile: String

        @OptionGroup
        var account: AccountOption

        struct Transfer: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CCDs to another account."
            )

            @OptionGroup
            var grpcCli: GrpcCli

            @OptionGroup
            var walletCli: LegacyWallet

            @OptionGroup
            var receiver: AccountOption

            @Option(help: "Amount of uCCD to send")
            var amount: MicroCcdAmount

            @Option(help: "Timestamp in Unix time of transaction expiry")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                // Load account from Legacy Wallet export.
                let exportContents = try Data(contentsOf: URL(fileURLWithPath: walletCli.exportFile))
                let export = try JSONDecoder().decode(LegacyWalletExportJson.self, from: exportContents)
                let wallet = try export.toWallet()

                let senderAddress = try walletCli.account.address
                let receiverAddress = try receiver.address
                print("Attempting to send \(amount) uCCD from account '\(senderAddress.base58Check)' to '\(receiverAddress.base58Check)'.")
                guard let senderAccount = wallet.lookup(address: senderAddress) else {
                    print("Export doesn't include account '\(senderAddress.base58Check)'.")
                    return
                }

                // Construct and send transaction.
                let hash = try await withClient(target: grpcCli.options.target) { client in
                    print("Resolving next sequence number of sender account.")
                    let next = try await client.nextAccountSequenceNumber(address: senderAddress)
                    print("Preparing transaction.")
                    let tx = AccountTransaction(
                        sender: senderAddress,
                        payload: .transfer(amount: amount, receiver: receiverAddress)
                    ).prepare(
                        sequenceNumber: next.sequenceNumber,
                        expiry: expiry,
                        signatureCount: senderAccount.keys.count
                    )
                    print("Signing transaction.")
                    let stx = try wallet.sign(transaction: tx)
                    print("Sending transaction.")
                    return try await client.send(transaction: stx)
                }
                print("Transaction with hash '\(hash.hex)' successfully submitted.")
            }
        }
    }
}

func withClient<T>(target: ConnectionTarget, _ cmd: (NodeClientProtocol) async throws -> T) async throws -> T {
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
    let client = GrpcNodeClient(channel: channel)
    return try await cmd(client)
}
