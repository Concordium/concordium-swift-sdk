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
            return
        }
        if let value = try? container.decode(UInt64.self) {
            self = .numeric(value: value)
            return
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
            self = .attributeInSet(statement: AttributeInSetStatementV2(attributeTag: attributeTag, set: set))
        case let .attributeNotInSet(attributeTag, set):
            self = .attributeNotInSet(statement: AttributeNotInSetStatementV2(attributeTag: attributeTag, set: set))
        case let .attributeInRange(attributeTag, lower, upper):
            self = .attributeInRange(statement: AttributeInRangeStatementV2(attributeTag: attributeTag, lower: lower, upper: upper))
        }
    }

    /// Used internally to convert from crypto lib outpub type to SDK type
    func toSDK() -> AtomicStatement<String, Web3IdAttribute> {
        switch self {
        case let .revealAttribute(statement): return .revealAttribute(attributeTag: statement.attributeTag)
        case let .attributeInSet(statement): return .attributeInSet(attributeTag: statement.attributeTag, set: statement.set)
        case let .attributeNotInSet(statement): return .attributeNotInSet(attributeTag: statement.attributeTag, set: statement.set)
        case let .attributeInRange(statement): return .attributeInRange(attributeTag: statement.attributeTag, lower: statement.lower, upper: statement.upper)
        }
    }

    public var attributeTag: String {
        switch self {
        case let .revealAttribute(statement): return statement.attributeTag
        case let .attributeInSet(statement): return statement.attributeTag
        case let .attributeNotInSet(statement): return statement.attributeTag
        case let .attributeInRange(statement): return statement.attributeTag
        }
    }
}

extension AtomicStatementV2: @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toSDK())
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
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

extension ConcordiumWalletCrypto.Did: @retroactive Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = try parseDidMethod(value: value)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(didMethodAsString(did: self))
    }
}

func getDateFormatter() -> ISO8601DateFormatter {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return dateFormatter
}

/**
 * A proof corresponding to one `VerifiableCredentialStatement`. This contains almost
 * all the information needed to verify it, except the issuer's public key in
 * case of the `Web3Id` proof, and the public commitments in case of the
 * `Account` proof.
 */
public typealias VerifiableCredentialProof = ConcordiumWalletCrypto.VerifiableCredentialProof
extension VerifiableCredentialProof: @retroactive Codable {
    private enum CodingKeys: CodingKey {
        case credentialSubject
        case type
        case issuer
    }

    static let CCD_TYPE = ["VerifiableCredential", "ConcordiumVerifiableCredential"]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let issuer = try container.decode(DID.self, forKey: .issuer)
        let credType = try container.decode([String].self, forKey: .type).filter { !Self.CCD_TYPE.contains($0) }

        switch issuer.idType {
        case let .idp(idpIdentity):
            let credSub = try container.decode(CredentialSubjectAccountJSON.self, forKey: .credentialSubject)

            var credId: Data
            switch credSub.id.idType {
            case let .credential(c): credId = c
            default:
                throw DecodingError.dataCorruptedError(forKey: .credentialSubject, in: container, debugDescription: "Only valid 'id' for IDP issued subject is .credential")
            }

            let statement = credSub.statement
            let proof = credSub.proof.proofValue
            guard statement.count == proof.count else {
                throw DecodingError.dataCorruptedError(forKey: .credentialSubject, in: container, debugDescription: "Expected equal number of statements and proofs in subject")
            }
            let proofs = zip(statement, proof).reduce(into: []) { acc, pair in
                acc.append(AccountStatementWithProof(statement: pair.0, proof: pair.1))
            }
            let created = try getDateFormatter().date(from: credSub.proof.created) ?! DecodingError.dataCorruptedError(forKey: .credentialSubject, in: container, debugDescription: "Expected ISO8601 formatted string for 'created' timestamp")

            self = .account(created: created, network: credSub.id.network, credId: credId, issuer: idpIdentity, proofs: proofs)
        case let .contractData(address, entrypoint, param):
            guard entrypoint == "issuer" else {
                throw DecodingError.dataCorruptedError(forKey: .issuer, in: container, debugDescription: "Expected 'issuer' entrypont in smart contract issuer DID")
            }
            guard param.count == 0 else {
                throw DecodingError.dataCorruptedError(forKey: .issuer, in: container, debugDescription: "Expected empty parameter in smart contract issuer DID")
            }
            let credSub = try container.decode(CredentialSubjectWeb3IdJSON.self, forKey: .credentialSubject)

            let statement = credSub.statement
            let proof = credSub.proof.proofValue
            guard statement.count == proof.count else {
                throw DecodingError.dataCorruptedError(forKey: .credentialSubject, in: container, debugDescription: "Expected equal number of statements and proofs in subject")
            }
            let proofs = zip(statement, proof).reduce(into: []) { acc, pair in
                acc.append(Web3IdStatementWithProof(statement: pair.0, proof: pair.1))
            }

            var holderId: Data
            switch credSub.id.idType {
            case let .publicKey(key):
                holderId = key
            default:
                throw DecodingError.dataCorruptedError(forKey: .credentialSubject, in: container, debugDescription: "Only valid 'id' for IDP issued subject is .credential")
            }
            let created = try getDateFormatter().date(from: credSub.proof.created) ?! DecodingError.dataCorruptedError(forKey: .credentialSubject, in: container, debugDescription: "Expected ISO8601 formatted string for 'created' timestamp")

            self = .web3Id(created: created, holderId: holderId, network: credSub.id.network, contract: address, credType: credType, commitments: credSub.proof.commitments, proofs: proofs)
        default:
            throw DecodingError.dataCorruptedError(forKey: .issuer, in: container, debugDescription: "The only valid variants for 'issuer' of verifiable credential are either .idp or .contractData")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .account(created, network, credId, issuer, proofsWithStatement):
            let (statements, proofs) = proofsWithStatement.reduce(into: ([AtomicStatementV1](), [AtomicProofV1]())) { acc, proof in
                acc.0.append(proof.statement)
                acc.1.append(proof.proof)
            }
            let proof = StatementProofAccountJSON(created: created, proofValue: proofs)
            let id = DID(network: network, idType: IdentifierType.credential(credId: credId))
            let credSub = CredentialSubjectAccountJSON(id: id, proof: proof, statement: statements)
            let issuer = DID(network: network, idType: IdentifierType.idp(idpIdentity: issuer))
            let json = JSON(credentialSubject: credSub, issuer: issuer)
            try container.encode(json)
        case let .web3Id(created, holderId, network, contract, credType, commitments, proofsWithStatement):
            let (statements, proofs) = proofsWithStatement.reduce(into: ([AtomicStatementV2](), [AtomicProofV2]())) { acc, proof in
                acc.0.append(proof.statement)
                acc.1.append(proof.proof)
            }
            let proof = StatementProofWeb3IdJSON(created: created, proofValue: proofs, commitments: commitments)
            let id = DID(network: network, idType: IdentifierType.publicKey(key: holderId))
            let credSub = CredentialSubjectWeb3IdJSON(id: id, proof: proof, statement: statements)
            let issuer = DID(network: network, idType: IdentifierType.contractData(address: contract, entrypoint: "issuer", parameter: Data()))
            let json = JSON(credentialSubject: credSub, issuer: issuer, additionalType: credType)
            try container.encode(json)
        }
    }

    private typealias DID = ConcordiumWalletCrypto.Did

    private struct JSON<CredentialSubject: Codable>: Codable {
        let credentialSubject: CredentialSubject
        let issuer: DID
        /// ["VerifiableCredential", "ConcordiumVerifiableCredential", ...]
        var type: [String]

        init(credentialSubject: CredentialSubject, issuer: DID, additionalType: [String]? = nil) {
            self.credentialSubject = credentialSubject
            self.issuer = issuer
            type = CCD_TYPE
            if let type = additionalType {
                self.type.append(contentsOf: type)
            }
        }
    }

    private struct CredentialSubjectJSON<Statement: Codable, Proof: Codable>: Codable {
        let id: DID
        let proof: Proof
        let statement: [Statement]
    }

    private struct StatementProofAccountJSON: Codable {
        /// ISO8601
        let created: String
        let proofValue: [AtomicProofV1]
        let type: String // "ConcordiumZKProofV3"

        init(created: Date, proofValue: [AtomicProofV1]) {
            self.created = getDateFormatter().string(from: created)
            self.proofValue = proofValue
            type = "ConcordiumZKProofV3"
        }
    }

    private struct StatementProofWeb3IdJSON: Codable {
        /// ISO8601
        let created: String
        let proofValue: [AtomicProofV2]
        let commitments: SignedCommitments
        let type: String // "ConcordiumZKProofV3"

        init(created: Date, proofValue: [AtomicProofV2], commitments: SignedCommitments) {
            self.created = getDateFormatter().string(from: created)
            self.proofValue = proofValue
            self.commitments = commitments
            type = "ConcordiumZKProofV3"
        }
    }

    private typealias CredentialSubjectAccountJSON = CredentialSubjectJSON<AtomicStatementV1, StatementProofAccountJSON>
    private typealias CredentialSubjectWeb3IdJSON = CredentialSubjectJSON<AtomicStatementV2, StatementProofWeb3IdJSON>
}

/// A proof that establishes that the owner of the credential has indeed created
/// the presentation. At present this is a list of signatures.
public typealias LinkingProof = ConcordiumWalletCrypto.LinkingProof

extension LinkingProof: @retroactive Codable {
    private struct JSON: Codable {
        /// Always "ConcordiumWeakLinkingProofV1"
        let type: String
        /// ISO8601
        let created: String
        /// Hex formatted strings
        let proofValue: [String]

        init(created: String, proofValue: [String]) {
            self.created = created
            self.proofValue = proofValue
            type = "ConcordiumWeakLinkingProofV1"
        }

        init(createdDate: Date, proofValue: [String]) {
            self = .init(created: getDateFormatter().string(from: createdDate), proofValue: proofValue)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let json = JSON(createdDate: created, proofValue: proofValue.map(\.hex))
        try container.encode(json)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode(JSON.self)
        let created = try getDateFormatter().date(from: json.created) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Expected ISO8601 formatted string for 'created' timestamp")
        self = try .init(created: created, proofValue: json.proofValue.map { try Data(hex: $0) })
    }
}

/// A presentation is the response to a `VerifiableCredentialRequest`. It contains proofs for
/// statements, ownership proof for all Web3 credentials, and a context. The
/// only missing part to verify the proof are the public commitments.
public typealias VerifiablePresentation = ConcordiumWalletCrypto.VerifiablePresentation

public extension VerifiablePresentation {
    /// Creates a verifiable presentation from:
    ///
    /// - Parameters:
    ///   - request: a set of verifiable credential statements + challenge (``VerifiablePresentationRequest``)
    ///   - global: the global context of the blockchain
    ///   - commitmentInputs: commitment inputs corresponding to the statements
    ///
    /// - Throws: if the presentation could not be successfully created.
    static func create(request: VerifiablePresentationRequest, global: CryptographicParameters, commitmentInputs: [VerifiableCredentialCommitmentInputs]) throws -> Self {
        try createVerifiablePresentation(request: request, global: global, commitmentInputs: commitmentInputs)
    }
}

extension VerifiablePresentation: @retroactive Codable {
    private struct JSON: Codable {
        /// Always "VerifiablePresentation"
        let type: String
        /// The challenge used for the presentation, hex formatted
        let presentationContext: String
        let verifiableCredential: [VerifiableCredentialProof]
        let proof: LinkingProof

        init(presentationContext: Data, verifiableCredential: [VerifiableCredentialProof], proof: LinkingProof) {
            type = "VerifiablePresentation"
            self.presentationContext = presentationContext.hex
            self.verifiableCredential = verifiableCredential
            self.proof = proof
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let json = JSON(presentationContext: presentationContext, verifiableCredential: verifiableCredential, proof: linkingProof)
        try container.encode(json)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode(JSON.self)
        self = try .init(presentationContext: Data(hex: json.presentationContext), verifiableCredential: json.verifiableCredential, linkingProof: json.proof)
    }
}

/// A full verifiable credential for Web3 ID credentials, including secrets.
public typealias Web3IdCredential = ConcordiumWalletCrypto.Web3IdCredential

// TODO: doc..
public enum VerifiablePresentationBuilderError: Error {
    case missingValue(tag: String)
    case missingRandomness(tag: String)
}

// TODO: doc..
public struct VerifiablePresentationBuilder {
    let challenge: Data
    let network: Network
    private var statements: [(VerifiableCredentialStatement, VerifiableCredentialCommitmentInputs)] = []

    public init(challenge: Data, network: Network) {
        self.challenge = challenge
        self.network = network
    }

    public mutating func verify(_ statement: [AtomicStatementV1], for idObject: IdentityObject, cred: AccountCredentialWithRandomness, issuer: UInt32) throws {
        try verify(statement, for: idObject, credId: CredentialRegistrationID(cred.credential.credId), randomness: cred.randomness, issuer: issuer)
    }

    public mutating func verify(_ statement: [AtomicStatementV1], for idObject: IdentityObject, credId: CredentialRegistrationID, randomness: Randomness, issuer: UInt32) throws {
        let attributes = statement.map(\.attributeTag)
        let (values, randomness) = try attributes.reduce(into: ([AttributeTag: String](), [AttributeTag: Data]())) { acc, tag in
            acc.0[tag] = try idObject.attributeList.chosenAttributes[tag] ?! VerifiablePresentationBuilderError.missingValue(tag: tag.description)
            acc.1[tag] = try randomness.attributesRand[tag] ?! VerifiablePresentationBuilderError.missingRandomness(tag: tag.description)
        }
        let verifiableStatement = VerifiableCredentialStatement.account(network: network, credId: credId.value, statement: statement)
        let commitmentInputs = VerifiableCredentialCommitmentInputs.account(issuer: issuer, values: values, randomness: randomness)
        statements.append((verifiableStatement, commitmentInputs))
    }

    public mutating func verify(_ statement: [AtomicStatementV2], for cred: Web3IdCredential, wallet: WalletSeed, credIndex: UInt32) throws {
        let signer = try wallet.signingKey(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes(issuer: IssuerSeedIndexes(index: cred.registry.index, subindex: cred.registry.subindex), index: credIndex))
        return try verify(statement, for: cred, signer: signer)
    }

    public mutating func verify(_ statement: [AtomicStatementV2], for cred: Web3IdCredential, signer: Data) throws {
        let attributes = statement.map(\.attributeTag)
        let (values, randomness) = try attributes.reduce(into: ([String: Web3IdAttribute](), [String: Data]())) { acc, tag in
            acc.0[tag] = try cred.values[tag] ?! VerifiablePresentationBuilderError.missingValue(tag: tag.description)
            acc.1[tag] = try cred.randomness[tag] ?! VerifiablePresentationBuilderError.missingRandomness(tag: tag.description)
        }
        let verifiableStatement = VerifiableCredentialStatement.web3Id(credType: cred.credentialType, network: network, contract: cred.registry, holderId: cred.holderId, statement: statement)
        let commitmentInputs = VerifiableCredentialCommitmentInputs.web3Issuer(signature: cred.signature, signer: signer, values: values, randomness: randomness)
        statements.append((verifiableStatement, commitmentInputs))
    }

    public func finalize(global: CryptographicParameters) throws -> VerifiablePresentation {
        let (statements, commitmentInputs) = self.statements.reduce(into: ([VerifiableCredentialStatement](), [VerifiableCredentialCommitmentInputs]())) { acc, row in
            acc.0.append(row.0)
            acc.1.append(row.1)
        }
        let request = VerifiablePresentationRequest(challenge: challenge, statements: statements)
        return try VerifiablePresentation.create(request: request, global: global, commitmentInputs: commitmentInputs)
    }
}

/// The different types of proofs, corresponding to the statements above.
public typealias AtomicProofV2 = ConcordiumWalletCrypto.AtomicProofV2

extension AtomicProofV2 {
    /// Used internally to convert from SDK type to crypto lib input
    init(sdkType: AtomicProof<Web3IdAttribute>) {
        switch sdkType {
        case let .revealAttribute(attribute, proof):
            self = .revealAttribute(attribute: attribute, proof: proof)
        case let .attributeInSet(proof):
            self = .attributeInSet(proof: proof)
        case let .attributeNotInSet(proof):
            self = .attributeNotInSet(proof: proof)
        case let .attributeInRange(proof):
            self = .attributeInRange(proof: proof)
        }
    }

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

extension AtomicProofV2: @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toSDK())
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try .init(sdkType: container.decode(AtomicProof<Web3IdAttribute>.self))
    }
}
