import XCTest
import Dispatch
import MiscKit

class MiscKitTests : XCTestCase {
    func testDbg() {
        dbg("test message")
        dbg("test message", "with", "arguments", nil, 1, 2, 3)
    }
}

