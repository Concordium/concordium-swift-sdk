import ConcordiumWalletCrypto
import Foundation

/// For the case where the verifier wants the user to show the value of an
/// attribute and prove that it is indeed the value inside the on-chain
/// commitment. Since the verifier does not know the attribute value before
/// seing the proof, the value is not present here.
public typealias RevealAttributeStatementV1 = ConcordiumWalletCrypto.RevealAttributeStatementV1
/// For the case where the verifier wants the user to prove that an attribute is
/// in a set of attributes.
public typealias AttributeInSetStatementV1 = ConcordiumWalletCrypto.AttributeInSetStatementV1
/// For the case where the verifier wants the user to prove that an attribute is
/// not in a set of attributes.
public typealias AttributeNotInSetStatementV1 = ConcordiumWalletCrypto.AttributeNotInSetStatementV1
/// For the case where the verifier wants the user to prove that an attribute is
/// in a range. The statement is that the attribute value lies in `[lower,
/// upper)` in the scalar field.
public typealias AttributeInRangeStatementV1 = ConcordiumWalletCrypto.AttributeInRangeStatementV1
/// Statements are composed of one or more atomic statements.
/// This type defines the different types of atomic statements.
public typealias AtomicStatementV1 = ConcordiumWalletCrypto.AtomicStatementV1

extension AtomicStatementV1: @retroactive Codable {
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

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let attributeTag = try container.decode(String.self, forKey: .attributeTag)

        switch type {
        case TypeValue.revealAttribute.rawValue:
            self = .revealAttribute(statement: RevealAttributeStatementV1(attributeTag: attributeTag))
        case TypeValue.attributeInSet.rawValue:
            let set = try container.decode([String].self, forKey: .set)
            self = .attributeInSet(statement: AttributeInSetStatementV1(attributeTag: attributeTag, set: set))
        case TypeValue.attributeNotInSet.rawValue:
            let set = try container.decode([String].self, forKey: .set)
            self = .attributeNotInSet(statement: AttributeNotInSetStatementV1(attributeTag: attributeTag, set: set))
        case TypeValue.attributeInRange.rawValue:
            let lower = try container.decode(String.self, forKey: .lower)
            let upper = try container.decode(String.self, forKey: .upper)
            self = .attributeInRange(statement: AttributeInRangeStatementV1(attributeTag: attributeTag, lower: lower, upper: upper))
        default:
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unexpected value found for 'type'"))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case let .revealAttribute(statement):
            try container.encode(statement.attributeTag, forKey: .attributeTag)
        case let .attributeInSet(statement):
            try container.encode(statement.attributeTag, forKey: .attributeTag)
            try container.encode(statement.set, forKey: .set)
        case let .attributeNotInSet(statement):
            try container.encode(statement.attributeTag, forKey: .attributeTag)
            try container.encode(statement.set, forKey: .set)
        case let .attributeInRange(statement):
            try container.encode(statement.attributeTag, forKey: .attributeTag)
            try container.encode(statement.lower, forKey: .lower)
            try container.encode(statement.upper, forKey: .upper)
        }
    }

    var type: String {
        switch self {
        case .revealAttribute: return TypeValue.revealAttribute.rawValue
        case .attributeInSet: return TypeValue.attributeInSet.rawValue
        case .attributeNotInSet: return TypeValue.attributeNotInSet.rawValue
        case .attributeInRange: return TypeValue.attributeInRange.rawValue
        }
    }
}

/// A statement is a list of atomic statements.
public typealias StatementV1 = ConcordiumWalletCrypto.StatementV1

extension StatementV1: @retroactive Codable {
    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let statements = try container.decode([AtomicStatementV1].self)
        self = Self(statements: statements)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for atomic in statements {
            try container.encode(atomic)
        }
    }
}

/// The different types of proofs, corresponding to the statements above.
public typealias AtomicProofV1 = ConcordiumWalletCrypto.AtomicProofV1

extension AtomicProofV1: @retroactive Codable {
    enum TypeValue: String {
        case revealAttribute = "RevealAttribute"
        case attributeInSet = "AttributeInSet"
        case attributeNotInSet = "AttributeNotInSet"
        case attributeInRange = "AttributeInRange"
    }

    enum CodingKeys: CodingKey {
        case type
        case attributeTag
        case proof
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let proof = try Data(hex: container.decode(String.self, forKey: .proof))

        switch type {
        case TypeValue.revealAttribute.rawValue:
            let attributeTag = try container.decode(String.self, forKey: .attributeTag)
            self = .revealAttribute(attribute: attributeTag, proof: proof)
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

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case let .revealAttribute(attributeTag, proof):
            try container.encode(attributeTag, forKey: .attributeTag)
            try container.encode(proof, forKey: .proof)
        case let .attributeInSet(proof):
            try container.encode(proof, forKey: .proof)
        case let .attributeNotInSet(proof):
            try container.encode(proof, forKey: .proof)
        case let .attributeInRange(proof):
            try container.encode(proof, forKey: .proof)
        }
    }

    var type: String {
        switch self {
        case .revealAttribute: return TypeValue.revealAttribute.rawValue
        case .attributeInSet: return TypeValue.attributeInSet.rawValue
        case .attributeNotInSet: return TypeValue.attributeNotInSet.rawValue
        case .attributeInRange: return TypeValue.attributeInRange.rawValue
        }
    }
}

/// A proof of a statement, composed of one or more atomic proofs.
public typealias ProofV1 = ConcordiumWalletCrypto.ProofV1

extension ProofV1: @retroactive Codable {
    enum CodingKeys: CodingKey {
        case proofs
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let proofs = try container.decode([AtomicProofV1].self, forKey: .proofs)
        self = .init(proofs: proofs)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(proofs, forKey: .proofs)
    }
}

/// A versioned variant of `ProofV1`
public typealias VersionedProofV1 = ConcordiumWalletCrypto.VersionedProofV1

extension VersionedProofV1: @retroactive Codable {
    public init(from decoder: any Decoder) throws {
        let v = try Versioned<ProofV1>(from: decoder)
        self.init(version: v.version, value: v.value)
    }

    public func encode(to encoder: any Encoder) throws {
        let v = Versioned(version: version, value: value)
        try v.encode(to: encoder)
    }
}
