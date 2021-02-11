import XCTest
@testable import MiscKit

final class MiscKitTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(MiscKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
