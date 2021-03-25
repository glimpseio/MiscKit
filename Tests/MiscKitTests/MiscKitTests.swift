#if !os(watchOS) // no testing on watchOS
import XCTest
import Dispatch
import MiscKit

class MiscKitTests : XCTestCase {
    @available(macOS 10.14, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testDbg() {
        dbg("test message")
        dbg("test message", "with", "arguments", nil, 1, 2, 3)
    }

    #if canImport(OSLog)
    @available(macOS 10.14, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func testPrf() {
        prf { dbg("block with no message") }
        prf("msg") { dbg("block with autoclosure message") }
        let _: Double = prf(msg: { "closure value message: \($0)" }) { 1.23}
    }
    #endif
    
    func testLoc() {
        XCTAssertEqual("1,234,567.890000", locfmt("%f", 1234567.890))
    }

    @available(*, deprecated)
    func testWip() {
        wip("this is a work-in-progress")
    }

    #if canImport(Dispatch)
    func testQMap() {
        XCTAssertEqual(Array(Int32(1)...99999), (Int64(1)...99999).qmap(concurrent: true) { Int32(String($0)) })
        XCTAssertThrowsError(try (Int64(1)...99999).qmap(concurrent: true) { i in throw err("fail #\(i)") })
    }
    #endif

    func testErr() {
        XCTAssertThrowsError(try { throw err("X") }())
    }

    func testCfg() {
        let str = cfg("X") { str in
            str += "YZ"
        }
        
        XCTAssertEqual("XYZ", str)
    }
}
#endif

