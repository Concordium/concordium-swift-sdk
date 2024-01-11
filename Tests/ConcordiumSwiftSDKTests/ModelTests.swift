import Foundation
@testable import ConcordiumSwiftSDK
import XCTest

class SequenceNumberTests: XCTestCase {

    func testInitialization() {
        let initialValue: UInt64 = 42

        let sequenceNumber = SequenceNumber(value: initialValue)

        XCTAssertEqual(sequenceNumber.value, initialValue, "Initialization should set the correct sequence number value")
    }

    func testNext() {
        var sequenceNumber = SequenceNumber(value: 42)

        let nextSequenceNumber = sequenceNumber.next()

        XCTAssertEqual(nextSequenceNumber.value, sequenceNumber.value + 1, "Next should return a new sequence number with an incremented value")
        XCTAssertEqual(sequenceNumber.value, 42, "Original instance should remain unchanged")
    }

    func testNextMut() {
        var sequenceNumber = SequenceNumber(value: 42)

        sequenceNumber.nextMut()

        XCTAssertEqual(sequenceNumber.value, 43, "NextMut should increment the sequence number in-place")
    }
}
