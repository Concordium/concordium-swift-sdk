import ConcordiumWalletCrypto
import CryptoKit
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
        let timestamp: String

        init(_ timestamp: Date) {
            type = .dateTime
            self.timestamp = getDateFormatter().string(from: timestamp)
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
        self = try .timestamp(value: getDateFormatter().date(from: value.timestamp) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Dates must be represented in ISO8601 format"))
    }
}

/**
 * For the case where the verifier wants the user to show the value of an
 * attribute and prove that it is indeed the value inside the on-chain
 * commitment. Since the verifier does not know the attribute value before
 * seing the proof, the value is not present here.
 */
public typealias RevealAttributeWeb3IdStatement = ConcordiumWalletCrypto.RevealAttributeWeb3IdStatement
/**
 * For the case where the verifier wants the user to prove that an attribute is
 * in a set of attributes.
 */
public typealias AttributeInSetWeb3IdStatement = ConcordiumWalletCrypto.AttributeInSetWeb3IdStatement
/**
 * For the case where the verifier wants the user to prove that an attribute is
 * not in a set of attributes.
 */
public typealias AttributeNotInSetWeb3IdStatement = ConcordiumWalletCrypto.AttributeNotInSetWeb3IdStatement
/**
 * For the case where the verifier wants the user to prove that an attribute is
 * in a range. The statement is that the attribute value lies in `[lower,
 * upper)` in the scalar field.
 */
public typealias AttributeInRangeWeb3IdStatement = ConcordiumWalletCrypto.AttributeInRangeWeb3IdStatement
/// Statements are composed of one or more atomic statements.
/// This type defines the different types of atomic statements.
public typealias AtomicWeb3IdStatement = ConcordiumWalletCrypto.AtomicWeb3IdStatement

extension AtomicWeb3IdStatement {
    /// Used internally to convert from SDK type to crypto lib input
    init(sdkType: AtomicStatement<String, Web3IdAttribute>) {
        switch sdkType {
        case let .revealAttribute(attributeTag):
            self = .revealAttribute(statement: RevealAttributeWeb3IdStatement(attributeTag: attributeTag))
        case let .attributeInSet(attributeTag, set):
            self = .attributeInSet(statement: AttributeInSetWeb3IdStatement(attributeTag: attributeTag, set: set))
        case let .attributeNotInSet(attributeTag, set):
            self = .attributeNotInSet(statement: AttributeNotInSetWeb3IdStatement(attributeTag: attributeTag, set: set))
        case let .attributeInRange(attributeTag, lower, upper):
            self = .attributeInRange(statement: AttributeInRangeWeb3IdStatement(attributeTag: attributeTag, lower: lower, upper: upper))
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

    /// Checks that a value can be proven for the atomic statement.
    /// This assumes that all values in the statement are comparable with the given value. If not, false is also returned.
    public func checkValue(value: Web3IdAttribute) -> Bool {
        switch self {
        case .revealAttribute: return true
        case let .attributeInSet(statement): return statement.set.contains(value)
        case let .attributeNotInSet(statement): return !statement.set.contains(value)
        case let .attributeInRange(statement):
            switch (statement.lower, statement.upper, value) {
            case let (.string(lower), .string(upper), .string(value)):
                return lower <= value && value < upper
            case let (.numeric(lower), .numeric(upper), .numeric(value)):
                return lower <= value && value < upper
            case let (.timestamp(lower), .timestamp(upper), .timestamp(value)):
                return lower <= value && value < upper
            default: return false
            }
        }
    }
}

extension AtomicWeb3IdStatement: @retroactive Codable {
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

/// Describes the differnet decentralized identifier variants
public typealias DID = ConcordiumWalletCrypto.Did

extension DID: @retroactive Codable {
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

/// Date formatter used to transform dates to the expected serializable form for verifiable credentials
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
            let (statements, proofs) = proofsWithStatement.reduce(into: ([AtomicIdentityStatement](), [AtomicIdentityProof]())) { acc, proof in
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
            let (statements, proofs) = proofsWithStatement.reduce(into: ([AtomicWeb3IdStatement](), [AtomicWeb3IdProof]())) { acc, proof in
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
                self.type.append(contentsOf: type.filter { !CCD_TYPE.contains($0) })
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
        let proofValue: [AtomicIdentityProof]
        let type: String // "ConcordiumZKProofV3"

        init(created: Date, proofValue: [AtomicIdentityProof]) {
            self.created = getDateFormatter().string(from: created)
            self.proofValue = proofValue
            type = "ConcordiumZKProofV3"
        }
    }

    private struct StatementProofWeb3IdJSON: Codable {
        /// ISO8601
        let created: String
        let proofValue: [AtomicWeb3IdProof]
        let commitments: SignedCommitments
        let type: String // "ConcordiumZKProofV3"

        init(created: Date, proofValue: [AtomicWeb3IdProof], commitments: SignedCommitments) {
            self.created = getDateFormatter().string(from: created)
            self.proofValue = proofValue
            self.commitments = commitments
            type = "ConcordiumZKProofV3"
        }
    }

    private typealias CredentialSubjectAccountJSON = CredentialSubjectJSON<AtomicIdentityStatement, StatementProofAccountJSON>
    private typealias CredentialSubjectWeb3IdJSON = CredentialSubjectJSON<AtomicWeb3IdStatement, StatementProofWeb3IdJSON>
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

extension Web3IdCredential: Codable {
    private struct JSON: Codable {
        let credentialSchema: CredentialSchema
        let credentialSubject: CredentialSubject
        let id: DID // .contractData
        let issuer: DID // .contractData
        let proof: Proof
        let randomness: [String: String] // [String: Hex]
        let type: [String]
        let validFrom: String // ISO8601 date
        let validUntil: String? // ISO8601 date

        struct CredentialSchema: Codable {
            let id: String
            let type: String // "JsonSchema2023"

            init(id: String) {
                self.id = id
                type = "JsonSchema2023"
            }
        }

        struct CredentialSubject: Codable {
            let attributes: [String: Web3IdAttribute]
            let id: DID // .publickKey
        }

        struct Proof: Codable {
            let proofPurpose: String // "assertionMethod"
            /// Hex encoded ``Data``
            let proofValue: String
            let type: String // "Ed25519Signature2020"
            let verificationMethod: DID // .publicKey

            init(proofValue: Data, verificationMethod: DID) {
                proofPurpose = "assertionMethod"
                self.proofValue = proofValue.hex
                type = "Ed25519Signature2020"
                self.verificationMethod = verificationMethod
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        let dateFormatter = getDateFormatter()

        let schema = JSON.CredentialSchema(id: credentialSchema)
        let subject = JSON.CredentialSubject(attributes: values, id: DID(network: network, idType: IdentifierType.publicKey(key: holderId)))
        let id = DID(network: network, idType: .contractData(address: registry, entrypoint: "credentialEntry", parameter: holderId))
        let issuer = DID(network: network, idType: .contractData(address: registry, entrypoint: "issuer", parameter: Data()))
        let proof = JSON.Proof(proofValue: signature, verificationMethod: DID(network: network, idType: .publicKey(key: issuerKey)))
        let json = JSON(
            credentialSchema: schema,
            credentialSubject: subject,
            id: id,
            issuer: issuer,
            proof: proof,
            randomness: randomness.mapValues(\.hex),
            type: credentialType,
            validFrom: dateFormatter.string(from: validFrom),
            validUntil: validUntil.map { dateFormatter.string(from: $0) }
        )
        try container.encode(json)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode(JSON.self)
        let dateFormatter = getDateFormatter()

        let validFrom = try dateFormatter.date(from: json.validFrom) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Expected 'validFrom' to contain ISO8601 formatted date")
        let validUntil = try json.validUntil.map {
            try dateFormatter.date(from: $0) ?! DecodingError.dataCorruptedError(in: container, debugDescription: "Expected 'validFrom' to contain ISO8601 formatted date")
        }
        let signature = try Data(hex: json.proof.proofValue)

        guard [json.id.network, json.credentialSubject.id.network, json.issuer.network, json.proof.verificationMethod.network].allSatisfy({ $0 == json.id.network }) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Network specified in all DID's must match")
        }
        let network = json.id.network

        let holderId: Data
        switch json.credentialSubject.id.idType {
        case let .publicKey(key): holderId = key
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Field 'id' must be smart contract DID with entrypoint 'credentialEntry'")
        }

        let issuerKey: Data
        switch json.proof.verificationMethod.idType {
        case let .publicKey(key): issuerKey = key
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Field 'id' must be smart contract DID with entrypoint 'credentialEntry'")
        }

        let registry: ContractAddress
        switch json.id.idType {
        case .contractData(let address, entrypoint: "credentialEntry", let parameter):
            guard parameter == holderId else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Field 'id' parameter substring must contain match the public key of the 'credentialSubject'")
            }
            registry = address
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Field 'id' must be smart contract DID with entrypoint 'credentialEntry'")
        }

        switch json.issuer.idType {
        case .contractData(let address, entrypoint: "issuer", parameter: Data()):
            guard address == registry else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Field 'issuer' must be smart contract DID with an address that matches the address specififed in the DID of the 'id' field")
            }
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Field 'issuer' must be smart contract DID with entrypoint 'issuer' and an empty parameter")
        }

        let randomness = try json.randomness.mapValues { try Data(hex: $0) }

        self = .init(
            holderId: holderId,
            network: network,
            registry: registry,
            credentialType: json.type,
            credentialSchema: json.credentialSchema.id,
            issuerKey: issuerKey,
            validFrom: validFrom,
            validUntil: validUntil,
            values: json.credentialSubject.attributes,
            randomness: randomness,
            signature: signature
        )
    }
}

/// Can be used to ease the construction of ``Verifiable Presentation``s
public struct VerifiablePresentationBuilder {
    /// The challenge used to construct the ``VerifiablePresentation``
    public let challenge: Data
    /// The network the verifiable credentials are created for
    public let network: Network
    private var statements: Set<PresentationInput> = Set()

    public init(challenge: Data, network: Network) {
        self.challenge = challenge
        self.network = network
    }

    /// Represents errors happening while building a ``VerifiablePresentation`` utilizing the ``VerifiablePresentationBuilder``
    public enum BuilderError: Error {
        /// A attribute value is missing for the attribute found in the statement provided
        case missingValue(tag: String)
        /// A randomness value is missing for the attribute found in the statement provided
        case missingRandomness(tag: String)
    }

    public struct IdStatementCheckError: Error, Equatable {
        /// The attributes that failed the check for a statement
        let attributes: [AttributeTag]
    }

    public struct Web3IdStatementCheckError: Error, Equatable {
        /// The attributes that failed the check for a statement
        let attributes: [String]
    }

    private struct PresentationInput: Equatable, Hashable {
        let statement: VerifiableCredentialStatement
        let commitmentInputs: VerifiableCredentialCommitmentInputs

        public func hash(into hasher: inout Hasher) {
            switch statement {
            case let .account(network, _, statement):
                hasher.combine(network)
                hasher.combine(statement)
            case let .web3Id(_, network, _, _, statement):
                hasher.combine(network)
                hasher.combine(statement)
            }
        }

        // Implement Equatable protocol (required for Hashable)
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs.statement, rhs.statement) {
            case let (.account(lNetwork, _, lStatement), .account(rNetwork, _, rStatement)): return lNetwork == rNetwork && lStatement == rStatement
            case let (.web3Id(_, lNetwork, _, _, lStatement), .web3Id(_, rNetwork, _, _, rStatement)): return lNetwork == rNetwork && lStatement == rStatement
            default: return false
            }
        }
    }

    /// Add a ``VerifiableCredentialProof`` of the supplied statement for the ``IdentityObject``
    /// - Parameters:
    ///   - statement: the statement to prove
    ///   - idObject: the identity to prove the `statement` for
    ///   - cred: the credential and associated randomness to use
    ///   - issuer: the identity issuer corresponding to the issuer used for the `idObject`
    /// - Throws: ``VerifiablePresentationBuilderError`` if the required values were not found for the parameters given
    /// - Returns: ``Result.error`` if any value provided does not pass a check for whether it can be proven, i.e. is within the bounds of the statement.
    @discardableResult public mutating func verify(_ statement: [AtomicIdentityStatement], for idObject: IdentityObject, cred: AccountCredentialWithRandomness, issuer: UInt32) throws -> Result<Void, IdStatementCheckError> {
        try verify(statement, values: idObject.attributeList.chosenAttributes, randomness: cred.randomness.attributesRand, credId: CredentialRegistrationID(cred.credential.credId), issuer: issuer)
    }

    /// Add a ``VerifiableCredentialProof`` of the supplied statement for the ``IdentityObject``
    /// - Parameters:
    ///   - statement: the statement to prove
    ///   - idObject: the identity to prove the `statement` for
    ///   - credId: the credential registration ID to use
    ///   - cred: the randomness corresponding to the credential
    ///   - issuer: the identity issuer corresponding to the issuer used for the `idObject`
    /// - Throws: ``VerifiablePresentationBuilderError`` if the required values were not found for the parameters given
    /// - Returns: ``Result.error`` if any value provided does not pass a check for whether it can be proven, i.e. is within the bounds of the statement.
    @discardableResult public mutating func verify(_ statement: [AtomicIdentityStatement], for idObject: IdentityObject, credId: CredentialRegistrationID, randomness: Randomness, issuer: UInt32) throws -> Result<Void, IdStatementCheckError> {
        try verify(statement, values: idObject.attributeList.chosenAttributes, randomness: randomness.attributesRand, credId: credId, issuer: issuer)
    }

    /// Add a ``VerifiableCredentialProof`` of the supplied statement for the supplied attribute values
    /// - Parameters:
    ///   - statement: the statement to prove
    ///   - values: the attribute values to use for the proof
    ///   - wallet: the wallet to derive values from
    ///   - credIndices: the credential indices used to derive values
    ///   - global: the cryptographic parameters of the chain
    /// - Throws: ``VerifiablePresentationBuilderError`` if the required values were not found for the parameters given
    /// - Returns: ``Result.error`` if any value provided does not pass a check for whether it can be proven, i.e. is within the bounds of the statement.
    @discardableResult public mutating func verify(_ statement: [AtomicIdentityStatement], for values: [AttributeTag: String], wallet: WalletSeed, credIndices: AccountCredentialSeedIndexes, global: CryptographicParameters) throws -> Result<Void, IdStatementCheckError> {
        let attributes = statement.map(\.attributeTag)
        let randomness = try attributes.reduce(into: [AttributeTag: Data]()) { acc, tag in
            acc[tag] = try wallet.attributeCommitmentRandomness(accountCredentialIndexes: credIndices, attribute: tag.rawValue)
        }
        let credId = try wallet.id(accountCredentialIndexes: credIndices, commitmentKey: global.onChainCommitmentKey)
        return try verify(statement, values: values, randomness: randomness, credId: credId, issuer: credIndices.identity.providerID)
    }

    /// Add a ``VerifiableCredentialProof`` of the supplied statement for the supplied attribute values
    /// - Parameters:
    ///   - statement: the statement to prove
    ///   - values: the attribute values to use for the proof
    ///   - randomness: the attribute randomness to use for the proof
    ///   - credId: the credential registration ID to use for the proof
    ///   - issuer: the identity issuer corresponding to the issuer for the credentials underlying identity
    /// - Throws: ``VerifiablePresentationBuilderError`` if the required values were not found for the parameters given
    /// - Returns: ``Result.error`` if any value provided does not pass a check for whether it can be proven, i.e. is within the bounds of the statement.
    @discardableResult public mutating func verify(_ statement: [AtomicIdentityStatement], values: [AttributeTag: String], randomness: [AttributeTag: Data], credId: CredentialRegistrationID, issuer: UInt32) throws -> Result<Void, IdStatementCheckError> {
        let attributes = statement.map(\.attributeTag)
        let (values, randomness) = try attributes.reduce(into: ([AttributeTag: String](), [AttributeTag: Data]())) { acc, tag in
            acc.0[tag] = try values[tag] ?! BuilderError.missingValue(tag: tag.description)
            acc.1[tag] = try randomness[tag] ?! BuilderError.missingRandomness(tag: tag.description)
        }

        let rejectedAttributes = statement.filter { !$0.checkValue(value: values[$0.attributeTag]!) }
            .map(\.attributeTag)
        if !rejectedAttributes.isEmpty {
            return .failure(IdStatementCheckError(attributes: rejectedAttributes))
        }

        let verifiableStatement = VerifiableCredentialStatement.account(network: network, credId: credId.value, statement: statement)
        let commitmentInputs = VerifiableCredentialCommitmentInputs.account(issuer: issuer, values: values, randomness: randomness)
        statements.update(with: PresentationInput(statement: verifiableStatement, commitmentInputs: commitmentInputs))
        return .success(())
    }

    /// Add a ``VerifiableCredentialProof`` of the supplied statement for the supplied ``Web3IdCredential``
    /// - Parameters:
    ///   - statement: the statement to prove
    ///   - cred: the credential to prove the statement for
    ///   - wallet: the wallet to derive the signing key of the credential
    ///   - credIndex: the credential index of the ``Web3IdCredential``
    /// - Throws: ``VerifiablePresentationBuilderError`` if the required values were not found for the parameters given
    /// - Returns: ``Result.error`` if any value provided does not pass a check for whether it can be proven, i.e. is within the bounds of the statement.
    @discardableResult public mutating func verify(_ statement: [AtomicWeb3IdStatement], for cred: Web3IdCredential, wallet: WalletSeed, credIndex: UInt32) throws -> Result<Void, Web3IdStatementCheckError> {
        let signer: Curve25519.Signing.PrivateKey = try wallet.signingKey(verifiableCredentialIndexes: VerifiableCredentialSeedIndexes(issuer: IssuerSeedIndexes(index: cred.registry.index, subindex: cred.registry.subindex), index: credIndex))
        return try verify(statement, for: cred, signer: signer)
    }

    /// Add a ``VerifiableCredentialProof`` of the supplied statement for the supplied ``Web3IdCredential``
    /// - Parameters:
    ///   - statement: the statement to prove
    ///   - cred: the credential to prove the statement for
    ///   - signer: the signing key for the credential
    /// - Throws: ``VerifiablePresentationBuilderError`` if the required values were not found for the parameters given
    /// - Returns: ``Result.error`` if any value provided does not pass a check for whether it can be proven, i.e. is within the bounds of the statement.
    @discardableResult public mutating func verify(_ statement: [AtomicWeb3IdStatement], for cred: Web3IdCredential, signer: Curve25519.Signing.PrivateKey) throws -> Result<Void, Web3IdStatementCheckError> {
        let attributes = statement.map(\.attributeTag)
        let (values, randomness) = try attributes.reduce(into: ([String: Web3IdAttribute](), [String: Data]())) { acc, tag in
            acc.0[tag] = try cred.values[tag] ?! BuilderError.missingValue(tag: tag.description)
            acc.1[tag] = try cred.randomness[tag] ?! BuilderError.missingRandomness(tag: tag.description)
        }
        let rejectedAttributes = statement.filter { !$0.checkValue(value: values[$0.attributeTag]!) }
            .map(\.attributeTag)
        if !rejectedAttributes.isEmpty {
            return .failure(Web3IdStatementCheckError(attributes: rejectedAttributes))
        }

        let verifiableStatement = VerifiableCredentialStatement.web3Id(credType: cred.credentialType, network: network, contract: cred.registry, holderId: cred.holderId, statement: statement)
        let commitmentInputs = VerifiableCredentialCommitmentInputs.web3Issuer(signature: cred.signature, signer: signer.rawRepresentation, values: values, randomness: randomness)
        statements.update(with: PresentationInput(statement: verifiableStatement, commitmentInputs: commitmentInputs))
        return .success(())
    }

    /// Finalize the ``VerifiablePresentation`` from the added verification rows
    /// - Parameter global: the cryptographic parameters of the chain
    /// - Throws: if the presentation could not be constructed
    /// - Returns: a ``VerifiablePresentation`` of the ``VerifiableCredentialStatement``s built in the context of the associated credentials and the global context of the associated chain.
    public func finalize(global: CryptographicParameters) throws -> VerifiablePresentation {
        let (statements, commitmentInputs) = self.statements.reduce(into: ([VerifiableCredentialStatement](), [VerifiableCredentialCommitmentInputs]())) { acc, row in
            acc.0.append(row.statement)
            acc.1.append(row.commitmentInputs)
        }
        let request = VerifiablePresentationRequest(challenge: challenge, statements: statements)
        return try VerifiablePresentation.create(request: request, global: global, commitmentInputs: commitmentInputs)
    }
}

/// The different types of proofs, corresponding to the statements above.
public typealias AtomicWeb3IdProof = ConcordiumWalletCrypto.AtomicWeb3IdProof

extension AtomicWeb3IdProof {
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

extension AtomicWeb3IdProof: @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toSDK())
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try .init(sdkType: container.decode(AtomicProof<Web3IdAttribute>.self))
    }
}
