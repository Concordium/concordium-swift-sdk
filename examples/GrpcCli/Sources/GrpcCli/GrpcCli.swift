import ArgumentParser
import ConcordiumSwiftSdk
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
        subcommands: [CryptographicParameters.self, Account.self, Wallet.self]
    )

    struct CryptographicParameters: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the cryptographic parameters of the chain."
        )

        @OptionGroup
        var grpc: GrpcCli

        @OptionGroup
        var block: BlockOption

        func run() async throws {
            let res = try await withClient(target: grpc.options.target) {
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
            var grpc: GrpcCli

            @OptionGroup
            var account: Account

            func run() async throws {
                let res = try await withClient(target: grpc.options.target) {
                    try await $0.nextAccountSequenceNumber(
                        address: account.account.address
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
            var grpc: GrpcCli

            @OptionGroup
            var block: BlockOption

            @OptionGroup
            var account: Account

            func run() async throws {
                let res = try await withClient(target: grpc.options.target) {
                    try await $0.info(
                        account: account.account.identifier,
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
            var grpc: GrpcCli

            @OptionGroup
            var wallet: Wallet

            @OptionGroup
            var receiver: AccountOption

            @Option(help: "Amount of uCCD to send")
            var amount: MicroCcdAmount

            @Option(help: "Timestamp in Unix time of transaction expiry")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                // Derive account.
                let seedHex = try Mnemonic.deterministicSeedString(from: wallet.seedPhrase)
                print("Resolved seed hex '\(seedHex)'.")
                let seed = WalletSeed(hex: seedHex, network: .testnet)
                let seedWallet = SeedBasedWallet(seed: seed)
                let account = try seedWallet.generateAccount(
                    credentials: [
                        IdentityCredential(
                            identity: Identity(providerIndex: wallet.identityProviderIndex, index: wallet.identityIndex),
                            counter: wallet.credentialCounter
                        ),
                    ],
                    commitmentKey: wallet.commitmentKey
                )

                print("Resolved address \(account.address.base58Check) from credential \(wallet.credentialCounter) of identity \(wallet.identityProviderIndex):\(wallet.identityIndex).")
                print("Attempting to send \(amount) uCCD from account '\(account.address.base58Check)' to '\(receiver.accountAddress)'.")

                // Construct and send transaction.
                let hash = try await withClient(target: grpc.options.target) { client in
                    print("Resolving next sequence number of sender account.")
                    let next = try await client.nextAccountSequenceNumber(address: account.address)
                    print("Preparing transaction.")
                    let tx = try AccountTransaction(
                        sender: account.address,
                        payload: .transfer(amount: amount, receiver: receiver.address)
                    ).prepare(
                        sequenceNumber: next.sequenceNumber,
                        expiry: expiry,
                        signatureCount: 1
                    )
                    print("Signing transaction.")
                    let hash = tx.serialize().hash
                    let signatures = try seedWallet.sign(hash, with: account)
                    let signed = SignedAccountTransaction(transaction: tx, signatures: signatures)
                    print("Sending transaction.")
                    // TODO: Why does the hash returned here differ from the one we signed??
                    return try await client.send(transaction: signed)
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
