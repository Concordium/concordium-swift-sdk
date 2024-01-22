@testable import ExampleWallet
import XCTest

class ExampleWalletTests: XCTestCase {
    var sut: SeedPhraseValidator!

    override func setUp() {
        sut = RealSeedPhraseValidator()
    }

    func testIsValidReturnsTrueWithValidSeedPhrase() {
        let validSeedPhrase = "flash tobacco obey genius army stove desk anchor quarter reflect chalk caution"
        XCTAssertTrue(sut.isValid(seedPhrase: validSeedPhrase))
    }

    func testIsValidReturnsFalseWithInvalidSeedPhrase() {
        let sut = RealSeedPhraseValidator()
        let invalidSeedPhrase = "flash tobacco obey genius army stove desk anchor quarter reflect chalk"
        XCTAssertFalse(sut.isValid(seedPhrase: invalidSeedPhrase))
    }
}
