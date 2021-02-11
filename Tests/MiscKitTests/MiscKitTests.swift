import XCTest
import Dispatch
import MiscKit

class MiscKitTests : XCTestCase {
    func testDbg() {
        dbg("test message")
        dbg("test message", "with", "arguments", nil, 1, 2, 3)
    }

    func testPrf() {
        prf { dbg("block with no message") }
        prf("msg") { dbg("block with autoclosure message") }
        let _: Double = prf(msg: { "closure value message: \($0)" }) { 1.23}
    }
}

