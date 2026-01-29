import Foundation
import ConcordiumWalletCrypto

public enum ZKPFactory {
    public static func makeVerifiablePresentationV1(
        request: RequestV1,
        global: GlobalContext,
        inputs: [OwnedCredentialProofPrivateInputs]
    ) throws -> ZKPPresentationV1 {
        let core = try createVerifiablePresentationV1(
            request: request,
            global: global,
            inputs: inputs
        )
        return try ZKPPresentationV1(from: core)
    }
}


