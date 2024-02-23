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

struct AccountOption: ParsableArguments, ExpressibleByArgument {
    @Argument(help: "Address of the account to interact with.")
    var accountAddress: String

    /// Initializer for implementing ``ParsableArguments`` which allows the type to be used as `@OptionGroup` fields.
    init() {
        accountAddress = ""
    }

    /// Initializer for implementing ``ExpressibleByArgument`` which allows the type to be used for `@Option` fields.
    init?(argument: String) {
        accountAddress = argument
    }

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

        @Option(help: "Seed phrase.")
        var seedPhrase: String

        @Option(help: "Commitment key for the relevant network.")
        var commitmentKey: String

        @Option(help: "Index of IP that issued identity.")
        var identityProviderIndex: UInt32

        @Option(help: "Index of identity issued by IP.")
        var identityIndex: UInt32

        @Option(help: "Index of credential derived from identity used to generate the account.")
        var credentialCounter: UInt8

        struct Transfer: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CCDs to another account."
            )

            @OptionGroup
            var grpcCli: GrpcCli

            @OptionGroup
            var walletCli: Wallet

            @Option(help: "Address of receiving account.")
            var receiver: AccountOption

            @Option(help: "Amount of uCCD to send.")
            var amount: MicroCcdAmount

            @Option(help: "Timestamp in Unix time of transaction expiry.")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                // Derive account and put it into wallet.
                let seedHex = try Mnemonic.deterministicSeedString(from: walletCli.seedPhrase)
                print("Resolved seed hex '\(seedHex)'.")
                let gen = SeedBasedAccountGenerator(
                    seed: WalletSeed(hex: seedHex, network: .testnet),
                    commitmentKey: walletCli.commitmentKey
                )
                let account = try gen.generateAccount(
                    credentials: [
                        AccountCredential(
                            identity: Identity(providerIndex: walletCli.identityProviderIndex, index: walletCli.identityIndex),
                            counter: walletCli.credentialCounter
                        ),
                    ]
                )
                print("Resolved address \(account.address.base58Check) from credential \(walletCli.credentialCounter) of identity \(walletCli.identityProviderIndex):\(walletCli.identityIndex).")

                let accountStore = SimpleAccountStore()
                accountStore.insert(account)
                let wallet = ConcordiumSwiftSdk.Wallet(accountStore: accountStore)

                // Construct and send transaction.
                let hash = try await withClient(target: grpcCli.options.target) { client in
                    try await transfer(
                        wallet: wallet,
                        client: client,
                        sender: account.address,
                        receiver: AccountAddress(base58Check: receiver.accountAddress),
                        amount: amount,
                        expiry: expiry
                    )
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

        @Option(help: "Address of account to interact with.")
        var account: AccountOption

        struct Transfer: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CCDs to another account."
            )

            @OptionGroup
            var grpcCli: GrpcCli

            @OptionGroup
            var walletCli: LegacyWallet

            @Option(help: "Address of receiving account.")
            var receiver: AccountOption

            @Option(help: "Amount of uCCD to send")
            var amount: MicroCcdAmount

            @Option(help: "Timestamp in Unix time of transaction expiry")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                // Load account from Legacy Wallet export.
                let exportContents = try Data(contentsOf: URL(fileURLWithPath: walletCli.exportFile))
                let export = try JSONDecoder().decode(LegacyWalletExportJson.self, from: exportContents)
                let accountStore = try SimpleAccountStore(export.toAccounts())

                let wallet = ConcordiumSwiftSdk.Wallet(accountStore: accountStore)

                // Construct and send transaction.
                let hash = try await withClient(target: grpcCli.options.target) { client in
                    try await transfer(
                        wallet: wallet,
                        client: client,
                        sender: walletCli.account.address,
                        receiver: receiver.address,
                        amount: amount,
                        expiry: expiry
                    )
                }
                print("Transaction with hash '\(hash.hex)' successfully submitted.")
            }
        }
    }
}

func transfer(wallet: Wallet, client: NodeClientProtocol, sender: AccountAddress, receiver: AccountAddress, amount: MicroCcdAmount, expiry: TransactionTime) async throws -> TransactionHash {
    print("Attempting to send \(amount) uCCD from account '\(sender.base58Check)' to '\(receiver.base58Check)'...")
    print("Resolving next sequence number of sender account.")
    let next = try await client.nextAccountSequenceNumber(address: sender)
    print("Preparing and signing transaction.")
    let tx = try wallet.prepareAndSign(
        transaction: AccountTransaction(
            sender: sender,
            payload: .transfer(amount: amount, receiver: receiver)
        ),
        sequenceNumber: next.sequenceNumber,
        expiry: expiry
    )
    print("Sending transaction.")
    return try await client.send(transaction: tx)
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
