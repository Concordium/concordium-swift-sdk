import ArgumentParser
import Concordium
import Foundation
import GRPC
import MnemonicSwift
import NIOPosix
import SwiftCBOR

enum CLIError: Error {
    case unsupportedNetwork(String)
}

struct GRPCOptions: ParsableArguments {
    @Option(help: "IP or DNS name of the Node.")
    var host = "grpc.testnet.concordium.com"

    @Option(help: "Port of the Node.")
    var port = 20000

    @Option(help: "Use HTTP without TLS encryption.")
    var insecure = false
}

struct WalletProxyOptions: ParsableArguments {
    @Option(help: "Base URL of WalletProxy instance.")
    var url: String = "https://wallet-proxy.testnet.concordium.com"

    var baseURL: URL {
        URL(string: url)!
    }
}

extension BlockIdentifier: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        do {
            self = try .hash(BlockHash(fromHex: argument))
        } catch {
            return nil
        }
    }
}

extension AccountAddress: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        do {
            try self.init(base58Check: argument)
        } catch {
            return nil
        }
    }
}

extension ModuleReference: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        do {
            try self.init(Data(hex: argument))
        } catch {
            return nil
        }
    }
}

extension ReceiveName: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        do {
            try self.init(argument)
        } catch {
            return nil
        }
    }
}

extension CCD: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        do {
            try self.init(argument, decimalSeparator: ".")
        } catch {
            print(error)
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
        subcommands: [
            CryptographicParameters.self,
            ConsensusInfo.self,
            ChainParameters.self,
            ElectionInfo.self,
            TokenomicsInfo.self,
            FinalizedBlocks.self,
            ModuleSource.self,
            InvokeInstance.self,
            Bakers.self,
            PoolInfo.self,
            PassivePoolInfo.self,
            GenerateSeedPhrase.self,
            Account.self,
            Wallet.self,
            LegacyWallet.self,
            IdentityProviders.self,
            AnonymityRevokers.self,
            Cis2.self,
        ]
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
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.cryptographicParameters(
                    block: block
                )
            }
            print(res)
        }
    }

    struct ConsensusInfo: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the consensus info of the chain."
        )

        @OptionGroup
        var rootCmd: Root

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.consensusInfo()
            }
            print(res)
        }
    }

    struct ChainParameters: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the parameters of the chain."
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.chainParameters(block: block)
            }
            print(res)
        }
    }

    struct ElectionInfo: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the election info of the chain."
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.electionInfo(block: block)
            }
            print(res)
        }
    }

    struct TokenomicsInfo: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display the tokenomics info of the chain."
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.tokenomicsInfo(block: block)
            }
            print(res)
        }
    }

    struct FinalizedBlocks: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display a continuous stream of finalized blocks"
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Number of blocks to stream. If not defined, the stream will not terminate until done so manually")
        var numBlocks: UInt?

        func run() async throws {
            try await withGRPCClient(rootCmd.opts) {
                var i = 0
                for try await info in $0.finalizedBlocks() {
                    print("finalized block: \(info.blockHash) at height: \(info.absoluteHeight)")

                    if numBlocks != nil {
                        i += 1
                        if i >= numBlocks! {
                            return
                        }
                    }
                }
            }
        }
    }

    struct ModuleSource: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display module source corresponding to module reference"
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        @Option(help: "Hex encoded module reference")
        var moduleRef: ModuleReference

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.source(moduleRef: moduleRef, block: block)
            }
            print(res)
        }
    }

    struct InvokeInstance: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display result of instance invocation"
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        @Option()
        var index: UInt64

        @Option()
        var subindex: UInt64 = 0

        @Option()
        var entrypoint: ReceiveName

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.invokeInstance(
                    request: ContractInvokeRequest(contract: ContractAddress(index: index, subindex: subindex), method: entrypoint),
                    block: block
                )
            }
            print(res)
        }
    }

    struct Bakers: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display a stream of bakers on chain"
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        func run() async throws {
            try await withGRPCClient(rootCmd.opts) {
                for try await baker in $0.bakers(block: block) {
                    print(baker)
                }
            }
        }
    }

    struct PoolInfo: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display a pool info for a baker pool"
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        @Option()
        var bakerId: BakerID

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.poolInfo(bakerId: bakerId, block: block)
            }
            print(res)
        }
    }

    struct PassivePoolInfo: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Display a pool info for the passive delegation pool"
        )

        @OptionGroup
        var rootCmd: Root

        @Option(help: "Hash of the block to query against.")
        var block: BlockIdentifier = .lastFinal

        func run() async throws {
            let res = try await withGRPCClient(rootCmd.opts) {
                try await $0.passiveDelegationInfo(block: block)
            }
            print(res)
        }
    }

    struct GenerateSeedPhrase: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Generate a fresh 24-word seed phrase for use in a new wallet."
        )

        // Strength 256 corresponds to 24 words
        // (see 'https://support.ledger.com/hc/en-us/articles/4415198323089-How-Ledger-device-generates-24-word-recovery-phrase?docs=true').
        @Option(help: "The strength to use. This must be a multiple of 32.")
        var strength: Int = 256

        func run() throws {
            let seedPhrase = try Mnemonic.generateMnemonic(strength: strength, language: .english)
            print(seedPhrase)
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
                let res = try await withGRPCClient(rootCmd.opts) {
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
                let res = try await withGRPCClient(rootCmd.opts) {
                    try await $0.info(
                        account: .address(accountCmd.address),
                        block: block
                    )
                }
                print(res)
            }
        }
    }

    struct Cis2: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Subcommands related to a particular CIS2 contract.",
            subcommands: [BalanceOf.self, TokenMetadata.self]
        )

        @Option()
        var index: UInt64

        @Option()
        var subindex: UInt64 = 0

        @Option()
        var tokenId: String = ""

        struct BalanceOf: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Display the of an address for a specific token ID in the contract"
            )

            @OptionGroup
            var rootCmd: Root

            @OptionGroup
            var cis2Cmd: Cis2

            @Option()
            var account: String

            func run() async throws {
                let res = try await withGRPCClient(rootCmd.opts) {
                    let client = try await CIS2.Contract(client: $0, address: ContractAddress(index: cis2Cmd.index, subindex: cis2Cmd.subindex))!
                    return try await client.balanceOf(CIS2.BalanceOfQuery(tokenId: CIS2.TokenID(Data(hex: cis2Cmd.tokenId))!, address: Address.account(AccountAddress(base58Check: account))))
                }
                print(res)
            }
        }

        struct TokenMetadata: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Display the metadata for a specific token ID in the contract"
            )

            @OptionGroup
            var rootCmd: Root

            @OptionGroup
            var cis2Cmd: Cis2

            func run() async throws {
                let res = try await withGRPCClient(rootCmd.opts) {
                    let client = try await CIS2.Contract(client: $0, address: ContractAddress(index: cis2Cmd.index, subindex: cis2Cmd.subindex))!
                    let metadata = try await client.tokenMetadata(CIS2.TokenID(Data(hex: cis2Cmd.tokenId))!)
                    return try await (metadata, metadata.get())
                }
                print(res)
            }
        }
    }

    struct Wallet: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Subcommands related to wallet activities.",
            subcommands: [Transfer.self, Identity.self, TransferToken.self]
        )

        @Option(help: "Seed phrase.")
        var seedPhrase: String

        @Option(help: "Network: 'mainnet' or 'testnet' (default).")
        var network: NetworkOption = .init(argument: "testnet")!

        @Option(help: "Index of IP that issued identity.")
        var identityProviderID: IdentityProviderID

        @Option(help: "Index of identity issued by IP.")
        var identityIndex: IdentityIndex

        struct TransferToken: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Transfer CIS2 to another account."
            )

            @OptionGroup
            var rootCmd: Root

            @OptionGroup
            var walletCmd: Wallet

            @Option(help: "Index of credential from which the sender account is derived.")
            var credentialCounter: CredentialCounter

            @Option(help: "Address of receiving account.")
            var receiver: AccountAddress

            @Option(help: "Amount of tokens to send.")
            var amount: UInt64

            @Option()
            var index: UInt64

            @Option()
            var subindex: UInt64 = 0

            @Option()
            var tokenId: String = ""

            func run() async throws {
                let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                print("Resolved seed hex '\(seedHex)'.")

                print("Fetching crypto parameters (for commitment key).")

                try await withGRPCClient(rootCmd.opts) { client in
                    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
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

                    let cis2 = try await CIS2.Contract(client: client, address: ContractAddress(index: index, subindex: subindex))!

                    let balance = try await cis2.balanceOf(CIS2.BalanceOfQuery(tokenId: CIS2.TokenID(Data([]))!, address: account.address))
                    guard balance.amount >= amount else {
                        print("Insufficient account balance: \(balance)")
                        return
                    }

                    let transfer = try CIS2.TransferPayload(
                        tokenId: CIS2.TokenID(Data(hex: tokenId))!,
                        amount: CIS2.TokenAmount(amount)!,
                        sender: account.address,
                        receiver: receiver
                    )

                    // Construct and send transaction.
                    var proposal = try await cis2.transfer(transfer, sender: account.address)
                    proposal.add(energy: 50) // Add some energy to ensure
                    let tx = try await proposal.send(signer: account.keys)
                    print("Transaction with hash '\(tx.hash)' successfully submitted. Waiting for finalization.")

                    let (blockHash, summary) = try await tx.waitUntilFinalized(timeoutSeconds: 10)
                    print("Transaction finalized in block \(blockHash): \(summary)")
                }
            }
        }

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

            @Option(help: "Amount of CCD to send.")
            var amount: CCD

            @Option(help: "Optional memo string.")
            var memo: String?

            @Option(help: "Timestamp in Unix time of transaction expiry.")
            var expiry: TransactionTime = 9_999_999_999

            func run() async throws {
                let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                print("Resolved seed hex '\(seedHex)'.")

                let memo = memo.map { Data(CBOR.encode($0)) }

                print("Fetching crypto parameters (for commitment key).")

                try await withGRPCClient(rootCmd.opts) { client in
                    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
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
                    let tx = try await transfer(
                        client: client,
                        sender: account,
                        receiver: receiver,
                        amount: amount,
                        memo: memo,
                        expiry: expiry
                    )
                    print("Transaction with hash '\(tx.hash)' successfully submitted. Waiting for finalization.")

                    let (blockHash, summary) = try await tx.waitUntilFinalized(timeoutSeconds: 10)
                    print("Transaction finalized in block \(blockHash): \(summary)")
                }
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
                    let cryptoParams = try await withGRPCClient(rootCmd.opts) {
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

                func fetchIdentityIssuance(request: IdentityVerificationStatusRequest) async throws -> IdentityVerificationResult {
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
                        print("Cannot find identity provider with ID \(walletCmd.identityProviderID).")
                        return
                    }

                    print("Fetching crypto parameters.")
                    let cryptoParams = try await withGRPCClient(rootCmd.opts) {
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
                    switch identity.result {
                    case let .failure(err):
                        print("Identity recovery failed: \(err)")
                    case let .success(identity):
                        print("Identity recovered successfully:")
                        print(identity)
                    }
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
                        print("Cannot find identity provider with ID \(walletCmd.identityProviderID).")
                        return
                    }

                    print("Fetching crypto parameters.")
                    let cryptoParams = try await withGRPCClient(rootCmd.opts) {
                        try await $0.cryptographicParameters(block: .lastFinal)
                    }

                    let seedHex = try Mnemonic.deterministicSeedString(from: walletCmd.seedPhrase)
                    let seed = try WalletSeed(seedHex: seedHex, network: walletCmd.network.network)
                    print("Preparing identity recovery request.")
                    let identityProvider = try ip.toSDKType()
                    let req = try makeIdentityRecoveryRequest(
                        seed: seed,
                        cryptoParams: cryptoParams,
                        identityProvider: identityProvider,
                        identityIndex: walletCmd.identityIndex
                    )
                    print("Recovering identity.")
                    let res = try await req.send(session: URLSession.shared)
                    let identity = try res.result.get() // unsafely assume success

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
                    let signedTx = try account.keys.sign(deployment: credential.credential, expiry: expiry)
                    print("Serializing credential deployment.")
                    let serializedTx = try signedTx.serialize()
                    print("Sending credential deployment.")
                    try await withGRPCClient(rootCmd.opts) { client in
                        let tx = try await client.send(deployment: serializedTx)
                        print("Transaction with hash '\(tx.hash)' successfully submitted. Waiting for finalization.")

                        let (blockHash, summary) = try await tx.waitUntilFinalized(timeoutSeconds: 10)
                        print("Transaction finalized in block \(blockHash): \(summary)")
                    }
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

            @Option(help: "Amount of CCD to send.")
            var amount: CCD

            @Option(help: "Optional memo string.")
            var memo: String?

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
                guard let sender = try export.toSDKType().first(where: { $0.address == walletCmd.account }) else {
                    print("Account \(walletCmd.account) not found in export.")
                    return
                }
                let memo = memo.map { Data(CBOR.encode($0)) }

                // Construct and send transaction.
                let (blockHash, summary) = try await withGRPCClient(rootCmd.opts) { client in
                    let tx = try await transfer(client: client, sender: sender, receiver: receiver, amount: amount, memo: memo, expiry: expiry)
                    print("Transaction with hash '\(tx.hash)' successfully submitted. Waiting for finalization.")
                    return try await tx.waitUntilFinalized(timeoutSeconds: 10)
                }

                print("Transaction finalized in block \(blockHash): \(summary)")
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
            try await withGRPCClient(rootCmd.opts) { client in
                let stream = client.anonymityRevokers(block: .lastFinal)
                for try await v in stream {
                    print(v)
                }
            }
        }
    }
}

func transfer(client: NodeClient, sender: Account, receiver: AccountAddress, amount: CCD, memo: Data?, expiry: TransactionTime) async throws -> SubmittedTransaction {
    print("Attempting to send \(amount) uCCD from account '\(sender.address.base58Check)' to '\(receiver.base58Check)'...")
    print("Resolving next sequence number of sender account.")
    let next = try await client.nextAccountSequenceNumber(address: sender.address)
    print("Preparing and signing transaction.")
    let tx = try sender.keys.sign(
        transaction: AccountTransaction.transfer(
            sender: sender.address,
            receiver: receiver, amount: amount, memo: memo != nil ? Memo(memo!) : nil
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
) throws -> IdentityVerificationStatusRequest {
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
    let statusURL = try runIdentityProviderFlow(identityProvider.metadata.issuanceStart, reqJSON)
    print("Identity verification process started!")
    return .init(url: statusURL)
}

func makeIdentityRecoveryRequest(
    seed: WalletSeed,
    cryptoParams: CryptographicParameters,
    identityProvider: IdentityProvider,
    identityIndex: IdentityIndex
) throws -> IdentityRecoveryRequest {
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

func withGRPCClient<T>(_ opts: GRPCOptions, _ f: (GRPCNodeClient) async throws -> T) async throws -> T {
    let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
    // Flip comment to use TLS (required for the official gRPC endpoints "grpc.testnet.concordium.com" etc.).
    let builder = opts.insecure
        ? ClientConnection.insecure(group: group)
        : ClientConnection.usingPlatformAppropriateTLS(for: group)
    let connection = builder.connect(host: opts.host, port: opts.port)
    let client = GRPCNodeClient(channel: connection)

    let res = try await f(client)

    // cleanup
    try! await connection.close().get()
    try! await group.shutdownGracefully()

    return res
}
