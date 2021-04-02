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

    func testParseXML() throws {
        #if os(Linux)
        // any XML with a processing instruction crashes on linux
        let supportsProcessingInstructions = false
        #else
        let supportsProcessingInstructions = true
        #endif

        func roundTrip(xml string: String, to result: String? = nil, quote: String = "\"", compactCloseTags: Bool = false, line: UInt = #line) throws {
            let item = try XMLTree.parse(data: string.data(using: .utf8) ?? .init())
            let xmlString = item.xmlString(declaration: "", quote: quote, compactCloseTags: compactCloseTags)
            XCTAssertEqual(result ?? string, xmlString, line: line)
        }

        try roundTrip(xml: "<x y='123'>z</x>", quote: "'")
        try roundTrip(xml: "<x y='ABC'> z </x>", quote: "'")
        try roundTrip(xml: "<x y='AB\\C'> z </x>", quote: "'")
        try roundTrip(xml: "<x y='123'> z <q:a><![CDATA[111]]><r><s></s><!-- COMMENT --></r></q:a> </x>", quote: "'")
        try roundTrip(xml: "<俄语 լեզու='ռուսերեն'>данные</俄语>", quote: "'")

        // https://www.w3.org/XML/Test/
        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/


        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/001.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/002.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc ></doc>", to: "<doc></doc>") // whitespace fidelity in tag not supported

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/008.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc>&amp;&lt;&gt;&quot;'</doc>", quote: "\"")
        try roundTrip(xml: "<doc>&amp;&lt;&gt;\"&apos;</doc>", quote: "'")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/093.xml?rev=1.2
        try roundTrip(xml: "<doc>\n\n</doc>")

        if supportsProcessingInstructions {
            // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/017.xml?rev=1.2
            try roundTrip(xml: "<doc><?pi some data ?><?x?></doc>")
            // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/016.xml?rev=1.1.1.1
            try roundTrip(xml: "<doc><?pi?></doc>")
        }

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/009.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc>&#x20;</doc>", to: "<doc> </doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/010.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc a1=\"v1\" ></doc>", to: "<doc a1=\"v1\"></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/011.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc a1=\"v1\" a2=\"v2\"></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/012.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc :=\"v1\"></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/013.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc _.-0123456789=\"v1\"></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/014.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc abcdefghijklmnopqrstuvwxyz=\"v1\"></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/018.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc><![CDATA[<foo>]]></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/019.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc><![CDATA[<&]]></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/020.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc><![CDATA[<&]>]]]></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/021.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc><!-- a comment --></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/022.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc><!-- a comment ->--></doc>")

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/025.xml?rev=1.1.1.1
        try roundTrip(xml: "<doc><foo/><foo><bar/></foo></doc>", compactCloseTags: true)

        // https://dev.w3.org/cvsweb/2001/XML-Test-Suite/xmlconf/xmltest/valid/sa/043.xml?rev=1.1.1.1
        //try roundTrip(xml: "<doc a1=\"foo\nbar\"></doc>")
    }

}
#endif

