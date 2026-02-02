import ConcordiumWalletCrypto
import Foundation

public struct ZKPPresentationV1: Codable {
    private static let verifiableCredentialType = "VerifiableCredential"
    private static let concordiumVerifiableCredentialV1Type = "ConcordiumVerifiableCredentialV1"
    private static let concordiumAccountBasedCredentialType = "ConcordiumAccountBasedCredential"
    private static let concordiumIdentityBasedCredentialType = "ConcordiumIdBasedCredential"

    public struct ContextProperty: Codable {
        public let label: String
        public let context: String
    }

    public struct Context: Codable {
        public let type: String
        public let given: [ContextProperty]
        public let requested: [ContextProperty]
    }

    public struct Proof: Codable {
        public let created: String
        public let proofValue: String
        public let type: String
    }

    public struct Statement: Codable {
        public enum StatementType: String, Codable {
            case attributeValue = "AttributeValue"
            case attributeInRange = "AttributeInRange"
            case attributeInSet = "AttributeInSet"
            case attributeNotInSet = "AttributeNotInSet"
        }

        public let type: StatementType
        public let attributeTag: String
        public let attributeValue: Web3IdAttribute?
        public let lower: Web3IdAttribute?
        public let upper: Web3IdAttribute?
        public let set: [Web3IdAttribute]?
    }

    public struct CredentialSubject: Codable {
        public let id: String
        public let statement: [Statement]
    }

    public struct VerifiableCredential: Codable {
        public let type: [String]
        public let credentialSubject: CredentialSubject
        public let validFrom: String?
        public let validUntil: String?
        public let issuer: String
        public let proof: Proof
    }

    public let type: [String]

    public let presentationContext: Context

    public let verifiableCredential: [VerifiableCredential]

    public let proof: Proof

    public init(
        type: [String],
        presentationContext: Context,
        verifiableCredential: [VerifiableCredential],
        proof: Proof
    ) {
        self.type = type
        self.presentationContext = presentationContext
        self.verifiableCredential = verifiableCredential
        self.proof = proof
    }
}

public extension ZKPPresentationV1 {
    init(from core: PresentationV1) throws {
        func string(from tag: AttributeTag) -> String {
            switch tag {
            case .firstName: return "firstName"
            case .lastName: return "lastName"
            case .sex: return "sex"
            case .dateOfBirth: return "dob"
            case .countryOfResidence: return "countryOfResidence"
            case .nationality: return "nationality"
            case .idDocType: return "idDocType"
            case .idDocNo: return "idDocNo"
            case .idDocIssuer: return "idDocIssuer"
            case .idDocIssuedAt: return "idDocIssuedAt"
            case .idDocExpiresAt: return "idDocExpiresAt"
            case .nationalIdNo: return "nationalIdNo"
            case .taxIdNo: return "taxIdNo"
            case .legalEntityId: return "lei"
            case .legalName: return "legalName"
            case .legalCountry: return "legalCountry"
            case .businessNumber: return "businessNumber"
            case .registrationAuth: return "registrationAuth"
            }
        }

        func hexString(_ data: Data) -> String {
            data.reduce(into: "") { acc, byte in
                acc.append(String(format: "%02x", byte))
            }
        }

        func hexStringFromHexOrBytes(_ data: Data) -> String {
            if let ascii = String(data: data, encoding: .utf8),
               ascii.count % 2 == 0,
               ascii.range(of: #"^[0-9a-fA-F]+$"#, options: .regularExpression) != nil
            {
                return ascii.lowercased()
            }
            return hexString(data)
        }

        func networkString(_ network: Network) -> String {
            switch network {
            case .testnet: return "testnet"
            case .mainnet: return "mainnet"
            }
        }

        func didForIdp(network: Network, idpIdentity: UInt32) -> String {
            "did:ccd:\(networkString(network)):idp:\(idpIdentity)"
        }

        func didForAccountCredential(network: Network, credId: Data) -> String {
            "did:ccd:\(networkString(network)):cred:\(hexStringFromHexOrBytes(credId))"
        }

        func didForIdentityCredential(network: Network, credId: Data) -> String {
            "did:ccd:\(networkString(network)):encidcred:\(hexStringFromHexOrBytes(credId))"
        }

        func mapStatement(_ stmt: AtomicStatementV1) -> Statement {
            switch stmt {
            case let .attributeValue(s):
                return Statement(
                    type: .attributeValue,
                    attributeTag: string(from: s.attributeTag),
                    attributeValue: s.attributeValue,
                    lower: nil,
                    upper: nil,
                    set: nil
                )
            case let .attributeInRange(s):
                return Statement(
                    type: .attributeInRange,
                    attributeTag: string(from: s.attributeTag),
                    attributeValue: nil,
                    lower: s.lower,
                    upper: s.upper,
                    set: nil
                )
            case let .attributeInSet(s):
                return Statement(
                    type: .attributeInSet,
                    attributeTag: string(from: s.attributeTag),
                    attributeValue: nil,
                    lower: nil,
                    upper: nil,
                    set: s.set
                )
            case let .attributeNotInSet(s):
                return Statement(
                    type: .attributeNotInSet,
                    attributeTag: string(from: s.attributeTag),
                    attributeValue: nil,
                    lower: nil,
                    upper: nil,
                    set: s.set
                )
            }
        }

        let context = Context(
            type: "ConcordiumContextInformationV1",
            given: core.presentationContext.given.map {
                ContextProperty(label: $0.label, context: $0.context)
            },
            requested: core.presentationContext.requested.map {
                ContextProperty(label: $0.label, context: $0.context)
            }
        )

        let formatter = getDateFormatter()

        let credentials: [VerifiableCredential] = core.verifiableCredentials.map { cred in
            switch cred {
            case .account(let account):
                let subject = CredentialSubject(
                    id: didForAccountCredential(network: account.subject.network, credId: account.subject.credId),
                    statement: account.subject.statements.map(mapStatement)
                )
                let issuer = didForIdp(network: account.subject.network, idpIdentity: account.issuer)
                let proof = Proof(
                    created: formatter.string(from: account.proofs.createdAt),
                    proofValue: hexString(account.proofs.proofValue),
                    type: "ConcordiumZKProofV4"
                )
                return VerifiableCredential(
                    type: [
                        Self.verifiableCredentialType,
                        Self.concordiumVerifiableCredentialV1Type,
                        Self.concordiumAccountBasedCredentialType,
                    ],
                    credentialSubject: subject,
                    validFrom: nil,
                    validUntil: nil,
                    issuer: issuer,
                    proof: proof
                )
            case .identity(let identity):
                let subject = CredentialSubject(
                    id: didForIdentityCredential(network: identity.subject.network, credId: identity.subject.credId),
                    statement: identity.subject.statements.map(mapStatement)
                )
                let issuer = didForIdp(network: identity.subject.network, idpIdentity: identity.issuer)
                let proof = Proof(
                    created: formatter.string(from: identity.proofs.createdAt),
                    proofValue: hexString(identity.proofs.proofValue),
                    type: "ConcordiumZKProofV4"
                )
                return VerifiableCredential(
                    type: [
                        Self.verifiableCredentialType,
                        Self.concordiumVerifiableCredentialV1Type,
                        Self.concordiumIdentityBasedCredentialType,
                    ],
                    credentialSubject: subject,
                    validFrom: formatter.string(from: identity.validFrom),
                    validUntil: formatter.string(from: identity.validUntil),
                    issuer: issuer,
                    proof: proof
                )
            }
        }

        let proof = Proof(
            created: formatter.string(from: core.linkingProof.createdAt),
            proofValue: hexString(core.linkingProof.proofValue),
            type: "ConcordiumWeakLinkingProofV1"
        )

        self.init(
            type: ["VerifiablePresentation", "ConcordiumVerifiablePresentationV1"],
            presentationContext: context,
            verifiableCredential: credentials,
            proof: proof
        )
    }
}
