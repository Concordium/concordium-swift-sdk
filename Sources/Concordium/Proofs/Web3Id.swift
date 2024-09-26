import ConcordiumWalletCrypto
import Foundation

/// A value of an attribute. This is the low-level representation. The
/// different variants are present to enable different representations in JSON,
/// and different embeddings as field elements when constructing and verifying
/// proofs.
public typealias Web3IdAttribute = ConcordiumWalletCrypto.Web3IdAttribute

extension Web3IdAttribute: @retroactive Codable {
    private enum AttributeType: String, Codable {
        case dateTime = "date-time"
    }

    private struct TimestampJSON: Codable {
        let type: AttributeType
        let timestamp: Date

        init(_ timestamp: Date) {
            type = .dateTime
            self.timestamp = timestamp
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .numeric(value): try container.encode(value)
        case let .timestamp(value):
            try container.encode(TimestampJSON(value))
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value: value)
        }
        if let value = try? container.decode(UInt64.self) {
            self = .numeric(value: value)
        }
        let value = try container.decode(TimestampJSON.self) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Failed to decode 'Web3IdAttribute'")
        self = .timestamp(value: value.timestamp)
    }
}

public typealias RevealAttributeStatementV2 = ConcordiumWalletCrypto.RevealAttributeStatementV2
public typealias AttributeInSetStatementV2 = ConcordiumWalletCrypto.AttributeInSetStatementV2
public typealias AttributeNotInSetStatementV2 = ConcordiumWalletCrypto.AttributeNotInSetStatementV2
public typealias AttributeInRangeStatementV2 = ConcordiumWalletCrypto.AttributeInRangeStatementV2
/// Statements are composed of one or more atomic statements.
/// This type defines the different types of atomic statements.
public typealias AtomicStatementV2 = ConcordiumWalletCrypto.AtomicStatementV2

extension AtomicStatementV2 {
    /// Used internally to convert from SDK type to crypto lib input
    init(sdkType: AtomicStatement<String, Web3IdAttribute>) {
        switch sdkType {
        case let .revealAttribute(attributeTag):
            self = .revealAttribute(statement: RevealAttributeStatementV2(attributeTag: attributeTag))
        case let .attributeInSet(attributeTag, set):
            self = .attributeInSet(statement: AttributeInSetStatementV2(attributeTag: attributeTag, set: [Web3IdAttribute](set)))
        case let .attributeNotInSet(attributeTag, set):
            self = .attributeNotInSet(statement: AttributeNotInSetStatementV2(attributeTag: attributeTag, set: [Web3IdAttribute](set)))
        case let .attributeInRange(attributeTag, lower, upper):
            self = .attributeInRange(statement: AttributeInRangeStatementV2(attributeTag: attributeTag, lower: lower, upper: upper))
        }
    }

    /// Used internally to convert from crypto lib outpub type to SDK type
    func toSDK() -> AtomicStatement<String, Web3IdAttribute> {
        switch self {
        case let .revealAttribute(statement): return .revealAttribute(attributeTag: statement.attributeTag)
        case let .attributeInSet(statement): return .attributeInSet(attributeTag: statement.attributeTag, set: Set(statement.set))
        case let .attributeNotInSet(statement): return .attributeNotInSet(attributeTag: statement.attributeTag, set: Set(statement.set))
        case let .attributeInRange(statement): return .attributeInRange(attributeTag: statement.attributeTag, lower: statement.lower, upper: statement.upper)
        }
    }
}

extension AtomicStatementV2: @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(toSDK())
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self = try .init(sdkType: container.decode(AtomicStatement<String, Web3IdAttribute>.self))
    }
}

/// A statement about a single credential, either an identity credential or a
/// Web3 credential.
public typealias VerifiableCredentialStatement = ConcordiumWalletCrypto.VerifiableCredentialStatement

/// A request for a proof. This is the statement and challenge. The secret data
/// comes separately.
public typealias VerifiablePresentationRequest = ConcordiumWalletCrypto.VerifiablePresentationRequest

/// The additional inputs, additional to the `VerifiablePresentationRequest` that are needed to
/// produce a `VerifablePresentation`.
public typealias VerifiableCredentialCommitmentInputs = ConcordiumWalletCrypto.VerifiableCredentialCommitmentInputs
/// A pair of a statement and a proof.
public typealias AccountStatementWithProof = ConcordiumWalletCrypto.AccountStatementWithProof
/// A pair of a statement and a proof.
public typealias Web3IdStatementWithProof = ConcordiumWalletCrypto.Web3IdStatementWithProof

/// Commitments signed by the issuer.
public typealias SignedCommitments = ConcordiumWalletCrypto.SignedCommitments

extension SignedCommitments: @retroactive Codable {
    private struct JSON: Codable {
        let signature: String // HexString
        let commitments: [String: String] // [String: HexString]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let commitments = commitments.reduce(into: [:]) { acc, pair in
            acc[pair.key] = pair.value.hex
        }
        try container.encode(JSON(signature: signature.hex, commitments: commitments))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode(JSON.self)
        let commitments = try json.commitments.reduce(into: [:]) { acc, pair in
            acc[pair.key] = try Data(hex: pair.value)
        }
        self = try .init(signature: Data(hex: json.signature), commitments: commitments)
    }
}

/**
 * A proof corresponding to one `VerifiableCredentialStatement`. This contains almost
 * all the information needed to verify it, except the issuer's public key in
 * case of the `Web3Id` proof, and the public commitments in case of the
 * `Account` proof.
 */
public typealias VerifiableCredentialProof = ConcordiumWalletCrypto.VerifiableCredentialProof
extension VerifiableCredentialProof: @retroactive Codable {}

/// A proof that establishes that the owner of the credential has indeed created
/// the presentation. At present this is a list of signatures.
public typealias LinkingProof = ConcordiumWalletCrypto.LinkingProof

extension LinkingProof: @retroactive Codable {}

/// A presentation is the response to a `VerifiableCredentialRequest`. It contains proofs for
/// statements, ownership proof for all Web3 credentials, and a context. The
/// only missing part to verify the proof are the public commitments.
public typealias VerifiablePresentation = ConcordiumWalletCrypto.VerifiablePresentation

extension VerifiablePresentation: @retroactive Codable {}

// TODO: maybe this can be removed??
extension ConcordiumWalletCrypto.AtomicStatementV2 {
    /// Used internally to convert from SDK type to crypto lib input
    init(statement: AtomicStatement<String, Web3IdAttribute>) {
        switch statement {
        case let .revealAttribute(attributeTag):
            self = .revealAttribute(statement: RevealAttributeStatementV2(attributeTag: attributeTag.description))
        case let .attributeInSet(attributeTag, set):
            self = .attributeInSet(statement: AttributeInSetStatementV2(attributeTag: attributeTag.description, set: [Web3IdAttribute](set)))
        case let .attributeNotInSet(attributeTag, set):
            self = .attributeNotInSet(statement: AttributeNotInSetStatementV2(attributeTag: attributeTag.description, set: [Web3IdAttribute](set)))
        case let .attributeInRange(attributeTag, lower, upper):
            self = .attributeInRange(statement: AttributeInRangeStatementV2(attributeTag: attributeTag.description, lower: lower, upper: upper))
        }
    }

    /// Used internally to convert from crypto lib outpub type to SDK type
    func toSDK() -> AtomicStatement<String, Web3IdAttribute> {
        switch self {
        case let .revealAttribute(statement):
            return .revealAttribute(attributeTag: statement.attributeTag)
        case let .attributeInSet(statement):
            return .attributeInSet(attributeTag: statement.attributeTag, set: Set(statement.set))
        case let .attributeNotInSet(statement):
            return .attributeNotInSet(attributeTag: statement.attributeTag, set: Set(statement.set))
        case let .attributeInRange(statement):
            return .attributeInRange(attributeTag: statement.attributeTag, lower: statement.lower, upper: statement.upper)
        }
    }
}

/// The different types of proofs, corresponding to the statements above.
public typealias AtomicProofV2 = ConcordiumWalletCrypto.AtomicProofV2

// TODO: maybe this can be removed??
extension ConcordiumWalletCrypto.AtomicProofV2 {
    /// Used internally to convert from crypto lib outpub type to SDK type
    func toSDK() -> AtomicProof<Web3IdAttribute> {
        switch self {
        case let .revealAttribute(attribute, proof): return .revealAttribute(attribute: attribute, proof: proof)
        case let .attributeInSet(proof): return .attributeInSet(proof: proof)
        case let .attributeNotInSet(proof): return .attributeNotInSet(proof: proof)
        case let .attributeInRange(proof): return .attributeInRange(proof: proof)
        }
    }
}
