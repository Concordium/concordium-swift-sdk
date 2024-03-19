import Foundation

public enum AttributeType: UInt8, CustomStringConvertible, CaseIterable {
    case firstName = 0
    case lastName = 1
    case sex = 2
    case dob = 3
    case countryOfResidence = 4
    case nationality = 5
    case idDocType = 6
    case idDocNo = 7
    case idDocIssuer = 8
    case idDocIssuedAt = 9
    case idDocExpiresAt = 10
    case nationalIdNo = 11
    case taxIdNo = 12
    case lei = 13

    public var description: String {
        switch self {
        case .firstName: return "firstName"
        case .lastName: return "lastName"
        case .sex: return "sex"
        case .dob: return "dob"
        case .countryOfResidence: return "countryOfResidence"
        case .nationality: return "nationality"
        case .idDocType: return "idDocType"
        case .idDocNo: return "idDocNo"
        case .idDocIssuer: return "idDocIssuer"
        case .idDocIssuedAt: return "idDocIssuedAt"
        case .idDocExpiresAt: return "idDocExpiresAt"
        case .nationalIdNo: return "nationalIdNo"
        case .taxIdNo: return "taxIdNo"
        case .lei: return "lei"
        }
    }
}
