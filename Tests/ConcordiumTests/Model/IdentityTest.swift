@testable import Concordium
import Foundation
import XCTest

final class IdentityTest: XCTestCase {
    func testCanInitializeAccountTagFromValidByte() {
        XCTAssertEqual(AttributeTag(rawValue: 0), AttributeTag.firstName)
        XCTAssertEqual(AttributeTag(rawValue: 1), AttributeTag.lastName)
        XCTAssertEqual(AttributeTag(rawValue: 2), AttributeTag.sex)
        XCTAssertEqual(AttributeTag(rawValue: 3), AttributeTag.dateOfBirth)
        XCTAssertEqual(AttributeTag(rawValue: 4), AttributeTag.countryOfResidence)
        XCTAssertEqual(AttributeTag(rawValue: 5), AttributeTag.nationality)
        XCTAssertEqual(AttributeTag(rawValue: 6), AttributeTag.idDocType)
        XCTAssertEqual(AttributeTag(rawValue: 7), AttributeTag.idDocNo)
        XCTAssertEqual(AttributeTag(rawValue: 8), AttributeTag.idDocIssuer)
        XCTAssertEqual(AttributeTag(rawValue: 9), AttributeTag.idDocIssuedAt)
        XCTAssertEqual(AttributeTag(rawValue: 10), AttributeTag.idDocExpiresAt)
        XCTAssertEqual(AttributeTag(rawValue: 11), AttributeTag.nationalIdNo)
        XCTAssertEqual(AttributeTag(rawValue: 12), AttributeTag.taxIdNo)
        XCTAssertEqual(AttributeTag(rawValue: 13), AttributeTag.legalEntityId)
    }

    func testCannotInitializeAccountTagFromInvalidByte() {
        XCTAssertNil(AttributeTag(rawValue: 250))
    }

    func testCanInitializeAccountTagFromValidString() {
        XCTAssertEqual(AttributeTag("firstName"), AttributeTag.firstName)
        XCTAssertEqual(AttributeTag("lastName"), AttributeTag.lastName)
        XCTAssertEqual(AttributeTag("sex"), AttributeTag.sex)
        XCTAssertEqual(AttributeTag("dob"), AttributeTag.dateOfBirth)
        XCTAssertEqual(AttributeTag("countryOfResidence"), AttributeTag.countryOfResidence)
        XCTAssertEqual(AttributeTag("nationality"), AttributeTag.nationality)
        XCTAssertEqual(AttributeTag("idDocType"), AttributeTag.idDocType)
        XCTAssertEqual(AttributeTag("idDocNo"), AttributeTag.idDocNo)
        XCTAssertEqual(AttributeTag("idDocIssuer"), AttributeTag.idDocIssuer)
        XCTAssertEqual(AttributeTag("idDocIssuedAt"), AttributeTag.idDocIssuedAt)
        XCTAssertEqual(AttributeTag("idDocExpiresAt"), AttributeTag.idDocExpiresAt)
        XCTAssertEqual(AttributeTag("lastName"), AttributeTag.lastName)
        XCTAssertEqual(AttributeTag("taxIdNo"), AttributeTag.taxIdNo)
        XCTAssertEqual(AttributeTag("lei"), AttributeTag.legalEntityId)
    }

    func testCannotInitializeAccountTagFromInvalidString() {
        XCTAssertNil(AttributeTag("xxx"))
    }

    func testDescription() {
        for a in AttributeTag.allCases {
            XCTAssertEqual(AttributeTag(a.description), a)
        }
    }
}
