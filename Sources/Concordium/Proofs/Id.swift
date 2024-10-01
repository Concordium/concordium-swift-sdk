import ConcordiumWalletCrypto
import Foundation

/// This is only used internally to deduplicate `Codable` implementations
enum AtomicStatement<Tag: Equatable, Value: Hashable & Equatable>: Equatable {
    /// For the case where the verifier wants the user to show the value of an
    /// attribute and prove that it is indeed the value inside the on-chain
    /// commitment. Since the verifier does not know the attribute value before
    /// seing the proof, the value is not present here.
    case revealAttribute(attributeTag: Tag)
    /// For the case where the verifier wants the user to prove that an attribute is
    /// in a set of attributes.
    case attributeInSet(attributeTag: Tag, set: [Value])
    /// For the case where the verifier wants the user to prove that an attribute is
    /// not in a set of attributes.
    case attributeNotInSet(attributeTag: Tag, set: [Value])
    /// For the case where the verifier wants the user to prove that an attribute is
    /// in a range. The statement is that the attribute value lies in `[lower,
    /// upper)` in the scalar field.
    case attributeInRange(attributeTag: Tag, lower: Value, upper: Value)
}

extension AtomicStatement: Codable where Tag: Codable, Value: Codable {
    enum TypeValue: String {
        case revealAttribute = "RevealAttribute"
        case attributeInSet = "AttributeInSet"
        case attributeNotInSet = "AttributeNotInSet"
        case attributeInRange = "AttributeInRange"
    }

    enum CodingKeys: CodingKey {
        case type
        case attributeTag
        case set
        case lower
        case upper
    }

    var type: String {
        switch self {
        case .revealAttribute: return TypeValue.revealAttribute.rawValue
        case .attributeInSet: return TypeValue.attributeInSet.rawValue
        case .attributeNotInSet: return TypeValue.attributeNotInSet.rawValue
        case .attributeInRange: return TypeValue.attributeInRange.rawValue
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let attributeTag = try container.decode(Tag.self, forKey: .attributeTag)

        switch type {
        case TypeValue.revealAttribute.rawValue:
            self = .revealAttribute(attributeTag: attributeTag)
        case TypeValue.attributeInSet.rawValue:
            let set = try container.decode([Value].self, forKey: .set)
            self = .attributeInSet(attributeTag: attributeTag, set: set)
        case TypeValue.attributeNotInSet.rawValue:
            let set = try container.decode([Value].self, forKey: .set)
            self = .attributeNotInSet(attributeTag: attributeTag, set: set)
        case TypeValue.attributeInRange.rawValue:
            let lower = try container.decode(Value.self, forKey: .lower)
            let upper = try container.decode(Value.self, forKey: .upper)
            self = .attributeInRange(attributeTag: attributeTag, lower: lower, upper: upper)
        default:
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unexpected value found for 'type'"))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case let .revealAttribute(attributeTag):
            try container.encode(attributeTag, forKey: .attributeTag)
        case let .attributeInSet(attributeTag, set):
            try container.encode(attributeTag, forKey: .attributeTag)
            try container.encode(set, forKey: .set)
        case let .attributeNotInSet(attributeTag, set):
            try container.encode(attributeTag, forKey: .attributeTag)
            try container.encode(set, forKey: .set)
        case let .attributeInRange(attributeTag, lower, upper):
            try container.encode(attributeTag, forKey: .attributeTag)
            try container.encode(lower, forKey: .lower)
            try container.encode(upper, forKey: .upper)
        }
    }
}

public typealias RevealAttributeStatementV1 = ConcordiumWalletCrypto.RevealAttributeStatementV1
public typealias AttributeInSetStatementV1 = ConcordiumWalletCrypto.AttributeInSetStatementV1
public typealias AttributeNotInSetStatementV1 = ConcordiumWalletCrypto.AttributeNotInSetStatementV1
public typealias AttributeInRangeStatementV1 = ConcordiumWalletCrypto.AttributeInRangeStatementV1
/// Statements are composed of one or more atomic statements.
/// This type defines the different types of atomic statements.
public typealias AtomicStatementV1 = ConcordiumWalletCrypto.AtomicStatementV1

extension AtomicStatementV1 {
    /// Used internally to convert from SDK type to crypto lib input
    init(sdkType: AtomicStatement<AttributeTag, String>) {
        switch sdkType {
        case let .revealAttribute(attributeTag):
            self = .revealAttribute(statement: RevealAttributeStatementV1(attributeTag: attributeTag))
        case let .attributeInSet(attributeTag, set):
            self = .attributeInSet(statement: AttributeInSetStatementV1(attributeTag: attributeTag, set: set))
        case let .attributeNotInSet(attributeTag, set):
            self = .attributeNotInSet(statement: AttributeNotInSetStatementV1(attributeTag: attributeTag, set: set))
        case let .attributeInRange(attributeTag, lower, upper):
            self = .attributeInRange(statement: AttributeInRangeStatementV1(attributeTag: attributeTag, lower: lower, upper: upper))
        }
    }

    /// Used internally to convert from crypto lib outpub type to SDK type
    func toSDK() -> AtomicStatement<AttributeTag, String> {
        switch self {
        case let .revealAttribute(statement): return .revealAttribute(attributeTag: statement.attributeTag)
        case let .attributeInSet(statement): return .attributeInSet(attributeTag: statement.attributeTag, set: statement.set)
        case let .attributeNotInSet(statement): return .attributeNotInSet(attributeTag: statement.attributeTag, set: statement.set)
        case let .attributeInRange(statement): return .attributeInRange(attributeTag: statement.attributeTag, lower: statement.lower, upper: statement.upper)
        }
    }

    public var attributeTag: AttributeTag {
        switch self {
        case let .revealAttribute(statement): return statement.attributeTag
        case let .attributeInSet(statement): return statement.attributeTag
        case let .attributeNotInSet(statement): return statement.attributeTag
        case let .attributeInRange(statement): return statement.attributeTag
        }
    }
}

extension AtomicStatementV1: @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toSDK())
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try .init(sdkType: container.decode(AtomicStatement<AttributeTag, String>.self))
    }
}

public typealias StatementV1 = ConcordiumWalletCrypto.StatementV1

public extension StatementV1 {
    /// Construct a proof corresponding to the statement for the identity in the given context
    /// - Parameters:
    ///   - wallet: The wallet to use when constructing the proof
    ///   - global: The cryptographic parameters of the chain
    ///   - credentialIndices: The indices used in the wallet seed for the credential used for the for the proof of identity
    ///   - identityObject: The identity object corresponding to the identity the statement should be proven for
    ///   - challenge: A challenge used, which is needed when verifying the proof
    ///
    /// - Throws: If the proof could not be successfully constructed given the context
    /// - Returns: A (versioned) proof of the statement for the identity in the given context
    func prove(
        wallet: WalletSeed,
        global: CryptographicParameters,
        credentialIndices: AccountCredentialSeedIndexes,
        identityObject: IdentityObject,
        challenge: Data
    ) throws -> VersionedProofV1 {
        try proveStatementV1(
            seed: wallet.seed,
            net: wallet.network,
            globalContext: global,
            ipIndex: credentialIndices.identity.providerID,
            identityIndex: credentialIndices.identity.index,
            credentialIndex: credentialIndices.counter,
            identityObject: identityObject,
            statement: self,
            challenge: challenge
        )
    }
}

extension StatementV1: Codable {
    private typealias JSON = [AtomicStatementV1]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let statements = try container.decode(JSON.self)
        self = Self(statements: statements)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(statements)
    }
}

/// This is only used internally to deduplicate `Codable` implementations
enum AtomicProof<Value: Equatable>: Equatable {
    /// Revealing an attribute and a proof that it equals the attribute value
    /// inside the attribute commitment.
    case revealAttribute(attribute: Value, proof: Data)
    /// A proof that an attribute is in a set
    case attributeInSet(proof: Data)
    /// A proof that an attribute is not in a set
    case attributeNotInSet(proof: Data)
    /// A proof that an attribute is in a range
    case attributeInRange(proof: Data)
}

extension AtomicProof: Codable where Value: Codable {
    enum TypeValue: String {
        case revealAttribute = "RevealAttribute"
        case attributeInSet = "AttributeInSet"
        case attributeNotInSet = "AttributeNotInSet"
        case attributeInRange = "AttributeInRange"
    }

    enum CodingKeys: CodingKey {
        case type
        case attribute
        case proof
    }

    var type: String {
        switch self {
        case .revealAttribute: return TypeValue.revealAttribute.rawValue
        case .attributeInSet: return TypeValue.attributeInSet.rawValue
        case .attributeNotInSet: return TypeValue.attributeNotInSet.rawValue
        case .attributeInRange: return TypeValue.attributeInRange.rawValue
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let proof = try Data(hex: container.decode(String.self, forKey: .proof))

        switch type {
        case TypeValue.revealAttribute.rawValue:
            let attribute = try container.decode(Value.self, forKey: .attribute)
            self = .revealAttribute(attribute: attribute, proof: proof)
        case TypeValue.attributeInSet.rawValue:
            self = .attributeInSet(proof: proof)
        case TypeValue.attributeNotInSet.rawValue:
            self = .attributeNotInSet(proof: proof)
        case TypeValue.attributeInRange.rawValue:
            self = .attributeInRange(proof: proof)
        default:
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unexpected value found for 'type'"))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case let .revealAttribute(attribute, proof):
            try container.encode(attribute, forKey: .attribute)
            try container.encode(proof.hex, forKey: .proof)
        case let .attributeInSet(proof):
            try container.encode(proof.hex, forKey: .proof)
        case let .attributeNotInSet(proof):
            try container.encode(proof.hex, forKey: .proof)
        case let .attributeInRange(proof):
            try container.encode(proof.hex, forKey: .proof)
        }
    }
}

/// The different types of proofs, corresponding to the statements above.
public typealias AtomicProofV1 = ConcordiumWalletCrypto.AtomicProofV1

extension AtomicProofV1 {
    /// Used internally to convert from SDK type to crypto lib input
    init(sdkType: AtomicProof<String>) {
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
    func toSDK() -> AtomicProof<String> {
        switch self {
        case let .revealAttribute(attribute, proof): return .revealAttribute(attribute: attribute, proof: proof)
        case let .attributeInSet(proof): return .attributeInSet(proof: proof)
        case let .attributeNotInSet(proof): return .attributeNotInSet(proof: proof)
        case let .attributeInRange(proof): return .attributeInRange(proof: proof)
        }
    }
}

extension AtomicProofV1: @retroactive Codable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toSDK())
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try .init(sdkType: container.decode(AtomicProof<String>.self))
    }
}

public typealias ProofV1 = ConcordiumWalletCrypto.ProofV1

extension ProofV1: @retroactive Codable {
    private struct JSON: Codable {
        let proofs: [AtomicProofV1]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(JSON(proofs: proofs))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(JSON.self)
        self = .init(proofs: value.proofs)
    }
}

public typealias VersionedProofV1 = ConcordiumWalletCrypto.VersionedProofV1

extension VersionedProofV1: @retroactive Codable {
    private typealias JSON = Versioned<ProofV1>

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(JSON(version: version, value: value))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(JSON.self)
        self = .init(version: value.version, value: value.value)
    }
}
