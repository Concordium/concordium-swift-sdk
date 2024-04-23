import ArgumentParser
import Concordium
import Foundation
import GRPC
import MnemonicSwift
import NIOPosix

enum CLIError: Error {
    case unsupportedNetwork(String)
}

struct GRPCOptions: ParsableArguments {
    @Option(help: "IP or DNS name of the Node.")
    var host = "localhost"

    @Option(help: "Port of the Node.")
    var port = 20000

    var target: ConnectionTarget {
        ConnectionTarget.host(host, port: port)
    }
}

struct WalletProxyOptions: ParsableArguments {
    @Option(help: "Base URL of WalletProxy instance.")
    var url: String = "https://wallet-proxy.testnet.concordium.com"

    var baseURL: URL {
        URL(string: url)!
    }
}

extension BlockIdentifier: ExpressibleByArgument {
    public init?(argument: String) {
        do {
            self = try .hash(BlockHash(hex: argument))
        } catch {
            return nil
        }
    }
}

extension AccountAddress: ExpressibleByArgument {
    public init?(argument: String) {
        do {
            try self.init(base58Check: argument)
        } catch {
            return nil
        }
    }
}

struct NetworkOption: ExpressibleByArgument {
    var string: String

    init?(argument: String) {
        string = argument
    }

    var network: Network {
        get throws {
            guard let res = Network(rawValue: string) else {
                throw CLIError.unsupportedNetwork(string)
            }
            return res
        }
    }
}

@main
struct Root: AsyncParsableCommand {
    @OptionGroup
    var opts: GRPCOptions

    static var configuration = CommandConfiguration(
        commandName: "concordium-example-client", // would be nice if this could be inferred from the CLI args (https://github.com/apple/swift-argument-parser/issues/633)
        abstract: "A CLI for demonstrating and testing use of the gRPC client of the SDK.",
        subcommands: [CryptographicParameters.self, Account.self, Wallet.self, LegacyWallet.self, IdentityProviders.self, AnonymityRevokers.self]
    )

    struct CryptographicParameters: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the cryptographic parameters of the chain."
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        func run() async throws {
            let res = try await withGRPCClient(target: rootCmd.opts.target) {
                try await $0.cryptographicParameters(
                    block: block
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

        @Option(help: "Address of the account to interact with.")
        var address: AccountAddress

        struct NextSequenceNumber: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Display the next sequence number of the provided account."
            )

            @OptionGroup
            var rootCmd: Root

            @OptionGroup
            var accountCmd: Account

            func run() async throws {
                let res = try await withGRPCClient(target: rootCmd.opts.target) {
                    try await $0.nextAccountSequenceNumber(
                        address: accountCmd.address
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
            var rootCmd: Root

            @OptionGroup
            var accountCmd: Account

            @Option(help: "Hash of the block to query against.")
            var block: BlockIdentifier = .lastFinal

            func run() async throws {
                let res = try await withGRPCClient(target: rootCmd.opts.target) {
                    try await $0.info(
                        account: .address(accountCmd.address),
                        block: block
                    )
                }
                print(res)
            }
        }
    }

    struct Wallet: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Subcommands related to wallet activities.",
            subcommands: [Transfer.self, Identity.self]
        )

        @Option(help: "Seed phrase.")
        var seedPhrase: String

        @Option(help: "Network: 'Mainnet' or 'Testnet' (default).")
        var network: NetworkOption = .init(argument: "Testnet")!

        @Option(help: "Index of IP that issued identity.")
        var identityProviderID: IdentityProviderID

        @Option(help: "Index of identity issued by IP.")
        var identityIndex: IdentityIndex

        struct Transfer: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CCDs to another account."
            )

            @OptionGroup
            var rootCmd: Root

            @OptionGroup
            var walletCmd: Wallet

            @Option(help: "Index of credential from which the sender account is derived.")
            var credentialCounter: CredentialCounter

            @Option(help: "Address of receiving account.")
            var receiver: AccountAddress

            @Option(help: "Amount of uCCD to send.")
            var amount: MicroCCDAmount

            @Option(help: "Timestamp in Unix time of transaction expiry.")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                print("Resolved seed hex '\(seedHex)'.")

                print("Fetching crypto parameters (for commitment key).")
                let hash = try await withGRPCClient(target: rootCmd.opts.target) { client in
                    let cryptoParams = try await client.cryptographicParameters(block: BlockIdentifier.lastFinal)
                    print("Deriving account address and keys.")
                    let account = try SeedBasedAccountDerivation(
                        seed: WalletSeed(seedHex: seedHex, network: walletCmd.network.network),
                        cryptoParams: cryptoParams
                    ).deriveAccount(
                        credentials: [
                            .init(
                                identity: .init(providerID: walletCmd.identityProviderID, index: walletCmd.identityIndex),
                                counter: credentialCounter
                            ),
                        ]
                    )
                    print("Resolved address \(account.address.base58Check) from credential \(credentialCounter) of identity \(walletCmd.identityProviderID):\(walletCmd.identityIndex).")

                    // Construct and send transaction.
                    return try await transfer(
                        client: client,
                        sender: account,
                        receiver: receiver,
                        amount: amount,
                        expiry: expiry
                    )
                }
                print("Transaction with hash '\(hash.hex)' successfully submitted.")
            }
        }

        struct Identity: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Subcommands for identity creation or recovery.",
                subcommands: [Issue.self, Recover.self, CreateAccount.self]
            )

            @OptionGroup
            var walletProxyOpts: WalletProxyOptions

            struct Issue: AsyncParsableCommand {
                static var configuration = CommandConfiguration(
                    abstract: "Issue identity."
                )

                @OptionGroup
                var rootCmd: Root

                @OptionGroup
                var walletCmd: Wallet

                @OptionGroup
                var identityCmd: Identity

                @Option(help: "Number of anonymity revokers needed to revoke anonymity.")
                var anonymityRevocationThreshold: UInt8 = 2

                func run() async throws {
                    let walletProxy = WalletProxy(baseURL: identityCmd.walletProxyOpts.baseURL)
                    guard let ip = try await findIdentityProvider(walletProxy: walletProxy, id: walletCmd.identityProviderID) else {
                        print("Cannot find identity provider with ID \(walletCmd.identityProviderID).")
                        return
                    }

                    print("Fetching crypto parameters.")
                    let cryptoParams = try await withGRPCClient(target: rootCmd.opts.target) {
                        try await $0.cryptographicParameters(block: .lastFinal)
                    }

                    let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                    let seed = try WalletSeed(seedHex: seedHex, network: walletCmd.network.network)

                    let identityReq = try issueIdentity(
                        seed: seed,
                        cryptoParams: cryptoParams,
                        identityProvider: ip.toSDKType(),
                        identityIndex: walletCmd.identityIndex,
                        anonymityRevocationThreshold: anonymityRevocationThreshold
                    ) { issuanceStartURL, requestJSON in
                        print("Starting temporary server waiting for identity verification to start.")
                        let res = try withIdentityIssuanceCallbackServer { callbackURL in
                            let urlBuilder = IdentityRequestURLBuilder(callbackURL: callbackURL)
                            let url = try urlBuilder.issuanceURLToOpen(baseURL: issuanceStartURL, requestJSON: requestJSON)
                            // TODO: Consider calling URL first to see if it succeeds (DTS staging returned an error directly without redirecting to the callback).
                            openURL(url: url)
                        }
                        print("Shutting down temporary server.")
                        return try res.get()
                    }

                    let res = try await fetchIdentityIssuance(request: identityReq)
                    switch res {
                    case let .failure(err):
                        print("Identity verification failed: \(err)")
                    case let .success(identity):
                        print("Identity successfully created:")
                        print(identity)
                    }
                }

                func openURL(url: URL) {
                    let p = Process()
                    p.launchPath = "/usr/bin/open"
                    p.arguments = [url.absoluteString]
                    p.launch()
                    p.waitUntilExit()
                }

                func fetchIdentityIssuance(request: IdentityIssuanceRequest) async throws -> IdentityVerificationResult {
                    var delaySecs: UInt64 = 1
                    while true {
                        print("Attempting to fetch identity.")
                        try await Task.sleep(nanoseconds: delaySecs * 1_000_000_000)
                        let res = try await request.send(session: URLSession.shared)
                        if let r = res.result {
                            // Verification result is ready.
                            return r
                        }
                        delaySecs = min(delaySecs * 2, 10) // exponential backoff (with limit)
                        var detailSuffix = ""
                        if let d = res.detail, !d.isEmpty {
                            detailSuffix = " (detail: \"\(d)\")"
                        }
                        print("Verification pending\(detailSuffix). Retrying in \(delaySecs) s.")
                    }
                }
            }

            struct Recover: AsyncParsableCommand {
                static var configuration = CommandConfiguration(
                    abstract: "Recover identity."
                )

                @OptionGroup
                var rootCmd: Root

                @OptionGroup
                var walletCmd: Wallet

                @OptionGroup
                var identityCmd: Identity

                func run() async throws {
                    let walletProxy = WalletProxy(baseURL: identityCmd.walletProxyOpts.baseURL)
                    guard let ip = try await findIdentityProvider(walletProxy: walletProxy, id: walletCmd.identityProviderID) else {
                        print("Cannot find identity with index \(walletCmd.identityProviderID).")
                        return
                    }

                    print("Fetching crypto parameters.")
                    let cryptoParams = try await withGRPCClient(target: rootCmd.opts.target) {
                        try await $0.cryptographicParameters(block: .lastFinal)
                    }

                    let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                    let seed = try WalletSeed(seedHex: seedHex, network: walletCmd.network.network)

                    print("Preparing identity recovery request.")
                    let req = try makeIdentityRecoveryRequest(
                        seed: seed,
                        cryptoParams: cryptoParams,
                        identityProvider: ip.toSDKType(),
                        identityIndex: walletCmd.identityIndex
                    )
                    print("Recovering identity.")
                    let identity = try await req.send(session: URLSession.shared)
                    print("Identity recovered successfully:")
                    print(identity)
                }
            }

            struct CreateAccount: AsyncParsableCommand {
                static var configuration = CommandConfiguration(
                    abstract: "Create new account on existing identity."
                )

                @OptionGroup
                var rootCmd: Root

                @OptionGroup
                var walletCmd: Wallet

                @OptionGroup
                var identityCmd: Identity

                @Option(help: "Index of credential derived from identity used to generate the account.")
                var credentialCounter: CredentialCounter

                @Option(help: "Timestamp in Unix time of transaction expiry.")
                var expiry: TransactionTime = 9_999_999_999

                func run() async throws {
                    let walletProxy = WalletProxy(baseURL: identityCmd.walletProxyOpts.baseURL)
                    guard let ip = try await findIdentityProvider(walletProxy: walletProxy, id: walletCmd.identityProviderID) else {
                        print("Cannot find identity with index \(walletCmd.identityProviderID).")
                        return
                    }

                    print("Fetching crypto parameters.")
                    let cryptoParams = try await withGRPCClient(target: rootCmd.opts.target) {
                        try await $0.cryptographicParameters(block: .lastFinal)
                    }

                    let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                    let seed = try WalletSeed(seedHex: seedHex, network: walletCmd.network.network)
                    print("Preparing identity recovery request.")
                    let identityProvider = ip.toSDKType()
                    let req = try makeIdentityRecoveryRequest(
                        seed: seed,
                        cryptoParams: cryptoParams,
                        identityProvider: identityProvider,
                        identityIndex: walletCmd.identityIndex
                    )
                    print("Recovering identity.")
                    let identity = try await req.send(session: URLSession.shared)

                    let idxs = AccountCredentialSeedIndexes(
                        identity: IdentitySeedIndexes(providerID: walletCmd.identityProviderID, index: walletCmd.identityIndex),
                        counter: credentialCounter
                    )
                    print("Deriving credential deployment.")
                    let accountDerivation = SeedBasedAccountDerivation(seed: seed, cryptoParams: cryptoParams)
                    let credential = try accountDerivation.deriveCredential(
                        seedIndexes: idxs,
                        identity: identity.value,
                        provider: identityProvider,
                        threshold: 1
                    )
                    print("Deriving account.")
                    let account = try accountDerivation.deriveAccount(credentials: [idxs])
                    print("Signing credential deployment.")
                    let signedTx = try account.keys.sign(deployment: credential, expiry: expiry)
                    print("Serializing credential deployment.")
                    let serializedTx = try signedTx.serialize()
                    print("Sending credential deployment.")
                    let hash = try await withGRPCClient(target: rootCmd.opts.target) { client in
                        try await client.send(deployment: serializedTx)
                    }
                    print("Transaction with hash '\(hash.hex)' successfully submitted.")
                }
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

        @Option
        var exportFilePassword: String

        @Option(help: "Address of account to interact with.")
        var account: AccountAddress

        struct Transfer: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CCDs to another account."
            )

            @OptionGroup
            var rootCmd: Root

            @OptionGroup
            var walletCmd: LegacyWallet

            @Option(help: "Address of receiving account.")
            var receiver: AccountAddress

            @Option(help: "Amount of uCCD to send.")
            var amount: MicroCCDAmount

            @Option(help: "Timestamp in Unix time of transaction expiry.")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                // Load account from Legacy Wallet export.
                print("Loading legacy wallet export from file '\(walletCmd.exportFile)' and decodig contents.")
                let exportContents = try Data(contentsOf: URL(fileURLWithPath: walletCmd.exportFile))
                let encryptedExport = try JSONDecoder().decode(LegacyWalletExportEncryptedJSON.self, from: exportContents)
                print("Decrypting export contents.")
                guard let password = walletCmd.exportFilePassword.data(using: .utf8) else {
                    print("Provided decryption password is not valid utf-8.")
                    return
                }
                let export = try decryptLegacyWalletExport(export: encryptedExport, password: password)
                print("Looking up account with address '\(walletCmd.account.base58Check)' in export.")
                guard let sender = try AccountStore(export.toSDKType()).lookup(walletCmd.account) else {
                    print("Account \(walletCmd.account) not found in export.")
                    return
                }

                // Construct and send transaction.
                let hash = try await withGRPCClient(target: rootCmd.opts.target) { client in
                    try await transfer(client: client, sender: sender, receiver: receiver, amount: amount, expiry: expiry)
                }
                print("Transaction with hash '\(hash.hex)' successfully submitted.")
            }
        }
    }

    struct IdentityProviders: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "List all Identity Providers."
        )

        @OptionGroup
        var walletProxyOptions: WalletProxyOptions

        func run() async throws {
            let walletProxy = WalletProxy(baseURL: walletProxyOptions.baseURL)
            let res = try await walletProxy.getIdentityProviders.send(session: URLSession.shared)
            print(res)
        }
    }

    struct AnonymityRevokers: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "List all Anonymity Revokers."
        )

        @OptionGroup
        var rootCmd: Root

        func run() async throws {
            let res = try await withGRPCClient(target: rootCmd.opts.target) { client in
                try await client.anonymityRevokers(block: .lastFinal)
            }
            print(res)
        }
    }
}

func transfer(client: NodeClient, sender: Account, receiver: AccountAddress, amount: MicroCCDAmount, expiry: TransactionTime) async throws -> TransactionHash {
    print("Attempting to send \(amount) uCCD from account '\(sender.address.base58Check)' to '\(receiver.base58Check)'...")
    print("Resolving next sequence number of sender account.")
    let next = try await client.nextAccountSequenceNumber(address: sender.address)
    print("Preparing and signing transaction.")
    let tx = try sender.keys.sign(
        transaction: AccountTransaction(
            sender: sender.address,
            payload: .transfer(amount: amount, receiver: receiver)
        ),
        sequenceNumber: next.sequenceNumber,
        expiry: expiry
    )
    print("Sending transaction.")
    return try await client.send(transaction: tx)
}

func findIdentityProvider(walletProxy: WalletProxy, id: IdentityProviderID) async throws -> IdentityProviderJSON? {
    let res = try await walletProxy.getIdentityProviders.send(session: URLSession.shared)
    return res.first { $0.ipInfo.ipIdentity == id }
}

func issueIdentity(
    seed: WalletSeed,
    cryptoParams: CryptographicParameters,
    identityProvider: IdentityProvider,
    identityIndex: IdentityIndex,
    anonymityRevocationThreshold: RevocationThreshold,
    runIdentityProviderFlow: (_ issuanceStartURL: URL, _ requestJSON: String) throws -> URL
) throws -> IdentityIssuanceRequest {
    print("Preparing identity issuance request.")
    let identityRequestBuilder = SeedBasedIdentityRequestBuilder(
        seed: seed,
        cryptoParams: cryptoParams
    )
    let reqJSON = try identityRequestBuilder.issuanceRequestJSON(
        provider: identityProvider,
        index: identityIndex,
        anonymityRevocationThreshold: anonymityRevocationThreshold
    )

    print("Start identity provider issuance flow.")
    let url = try runIdentityProviderFlow(identityProvider.metadata.issuanceStart, reqJSON)
    print("Identity verification process started!")
    return .init(url: url)
}

func makeIdentityRecoveryRequest(
    seed: WalletSeed,
    cryptoParams: CryptographicParameters,
    identityProvider: IdentityProvider,
    identityIndex: IdentityIndex
) throws -> IdentityRecoverRequest {
    let identityRequestBuilder = SeedBasedIdentityRequestBuilder(
        seed: seed,
        cryptoParams: cryptoParams
    )
    let reqJSON = try identityRequestBuilder.recoveryRequestJSON(
        provider: identityProvider.info,
        index: identityIndex,
        time: Date.now
    )
    let urlBuilder = IdentityRequestURLBuilder(callbackURL: nil)
    return try urlBuilder.recoveryRequest(
        baseURL: identityProvider.metadata.recoveryStart,
        requestJSON: reqJSON
    )
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
