import Common

// Inputs.
let seedPhrase = "fence tongue sell large master side flock bronze ice accident what humble bring heart swear record valley party jar caution horn cushion endorse position"
let identityProviderID = 3
let identityIndex = 7
let credentialCounter = 21

withGRPCClient { client in
    // Fetch parameters from chain.
    let cryptoParams = try await client.cryptographicParameters(block: .lastFinal)
    // Resolve next sequence number of account.
    let nextSeq = try await client.nextAccountSequenceNumber(address: account.address)
}
