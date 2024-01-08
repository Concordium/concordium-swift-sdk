@testable import ConcordiumSwiftSDK
import XCTest

struct ExampleStruct {
    var property1: String?
    var property2: Int?
}

final class ScopeFunctionsTests: XCTestCase {

    func testWith() {
        let myObject = with(ExampleStruct()) {
            $0.property1 = "Hello"
            $0.property2 = 42
        }

        XCTAssertEqual(myObject.property1, "Hello")
        XCTAssertEqual(myObject.property2, 42)
    }
}
