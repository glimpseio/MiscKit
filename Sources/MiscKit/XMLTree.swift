// Various misc utilities
// Marc Prud'hommeaux, 2014-2021

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// An XML Element Tree.
@available(macOS 10.14, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct XMLTree : Hashable {
    public struct Entity : OptionSet {
        /// The format's default value.
        public let rawValue: UInt

        /// Creates an Entity value with the given raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static var lt: Entity { return Entity(rawValue: 1 << 0) }
        public static var amp: Entity { return Entity(rawValue: 1 << 1) }
        public static var gt: Entity { return Entity(rawValue: 1 << 2) }
        public static var quot: Entity { return Entity(rawValue: 1 << 3) }
        public static var apos: Entity { return Entity(rawValue: 1 << 4) }
    }

    /// A single XML document
    public static let document = XMLTree(elementName: "")

    public var elementName: String
    public var attributes: [String : String]
    public var children: [Child]
    public var namespaceURI: String?
    public var qualifiedName: String?

    /// This is the document root, which is the only one that permits an empty element name
    public var isDocument: Bool { return elementName == "" }

    /// Returns all the children of this tree that are element nodes
    public var elementChildren: [XMLTree] {
        return children.compactMap { child in
            if case .element(let element) = child { return element }
            return nil
        }
    }

    /// Returns all the elements in a flattened list
    public var flattenedElements: [XMLTree] {
        return self.elementChildren + self.elementChildren.map(\.flattenedElements).joined()
    }

    /// The attributes for this element
    public subscript(attribute name: String) -> String? {
        get { return attributes[name] }
        set { attributes[name] = newValue }
    }

    /// A `Child` consists of all the data strucutres that may be contained within an XML element.
    public enum Child : Hashable {
        case element(XMLTree)
        case content(String)
        case comment(String)
        case cdata(Data)
        case whitespace(String)
        case processingInstruction(target: String, data: String?)
    }

    public init(elementName: String, attributes: [String : String] = [:], children: [Child] = [], namespaceURI: String? = nil, qualifiedName: String? = nil) {
        self.elementName = elementName
        self.attributes = attributes
        self.children = children
        self.namespaceURI = namespaceURI
        self.qualifiedName = qualifiedName
    }

    /// Appends the given tree as an element child
    public mutating func append(_ element: XMLTree) {
        self.children.append(.element(element))
    }

    /// Adds the given element to the node.
    /// - Parameters:
    ///   - elementName: the name of the element
    ///   - attributes: any attributes for the element
    ///   - content: the textual content of the element
    ///   - CDATA: whether the text content should be in a CDATA tag (default: false)
    /// - Returns: the appended XMLTree
    @discardableResult public mutating func addElement(_ elementName: String, attributes: [String: String] = [:] , content: String? = nil, CDATA: Bool = false) -> XMLTree {
        var node = XMLTree(elementName: elementName, attributes: attributes)
        if let content = content {
            if CDATA {
                node.children.append(.cdata(content.data(using: .utf8) ?? .init()))
            } else {
                node.children.append(.content(content))
            }
        }
        self.children.append(.element(node))
        return self
    }

    public func xmlString(declaration: String = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", quote: String = "\"", compactCloseTags: Bool = false, escape entities: Entity = [.lt, .amp, .gt], commentScriptCDATA: Bool = false, attributeSorter: ([String: String]) -> [(String, String)] = { Array($0).sorted(by: { $0.0 < $1.0 }) }) -> String {
        var str = ""

        // when we use single quotes for entites, we escape them; same for double-quotes
        var entities = entities
        entities.insert(quote == "\"" ? .quot : .apos)

        if isDocument {
            str += declaration // the document header is the XML declaration
        } else {
            str += "<" + elementName
            for (key, value) in attributeSorter(attributes) {
                str += " " + key + "=" + quote + value.escapedXMLEntities(entities) + quote
            }
            if children.isEmpty && compactCloseTags {
                str += "/"
            }
            str += ">"
        }

        for child in children {
            switch child {
            case .element(let element):
                str += element.xmlString(quote: quote, compactCloseTags: compactCloseTags, escape: entities, commentScriptCDATA: commentScriptCDATA, attributeSorter: attributeSorter)
            case .content(let content):
                str.append(content.escapedXMLEntities(entities))
            case .comment(let comment):
                str += "<!--" + comment + "-->"
            case .cdata(let data):
                // note that we manually replace "]]>" with "]] >" in order to prevent it from breaking the CDATA
                // this is potentially dangerous, because the code might contains "]]>" that runs in a meaningful way.
                let code = (String(data: data, encoding: .utf8)?.replacingOccurrences(of: "]]>", with: "]] >") ?? "")
                //dbg("CDATA", data.localizedByteCount, elementName)
                if commentScriptCDATA && elementName == "script" {
                    // https://www.w3.org/TR/html-polyglot/#dfn-safe-text-content
                    str += "//<![CDATA[\n" + code + "\n//]]>"
                } else {
                    str += "<![CDATA[" + code + "]]>"
                }
            case .whitespace(let whitespace):
                str += whitespace
            case .processingInstruction(let target, let data):
                str += "<?" + target
                if let data = data {
                    str += " " + data
                }
                str += "?>"
            }
        }

        if !isDocument && !(children.isEmpty && compactCloseTags) {
            str += "</" + elementName + ">"
        }

        return str
    }

    /// Parses the given `Data` and returns an `XMLTree`
    public static func parse(data: Data, shouldProcessNamespaces: Bool = true, shouldReportNamespacePrefixes: Bool = true, entityResolver: ((_ name: String, _ systemID: String?) -> (Data?))? = nil) throws -> XMLTree {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = shouldProcessNamespaces
        parser.shouldReportNamespacePrefixes = shouldReportNamespacePrefixes

        let delegate = Delegate()
        if let entityResolver = entityResolver {
            parser.shouldResolveExternalEntities = true
            delegate.entityResolver = entityResolver
        } else {
            parser.shouldResolveExternalEntities = false
        }

        parser.delegate = delegate
        if parser.parse() == false {
            if let error = parser.parserError {
                throw error
            } else if let parseError = delegate.parseErrors.first {
                throw parseError
            } else if let validationError = delegate.validationErrors.first {
                throw validationError
            } else {
                throw err(loc("Unable to parse XML document"))
            }
        }

        if delegate.elements.count != 1 {
            throw err(locfmt("Bad element count %d", delegate.elements.count))
        }

        return delegate.currentElement
    }

    private class Delegate : NSObject, XMLParserDelegate {
        var elements: [XMLTree] = []
        var parseErrors: [Error] = []
        var validationErrors: [Error] = []
        var entityResolver: (_ name: String, _ systemID: String?) -> (Data?) = { _, _ in nil}

        /// Convenience getter/setter for the button of the elements stack
        var currentElement: XMLTree {
            get {
                return elements.last!
            }

            set {
                if elements.isEmpty {
                    elements = [newValue]
                } else {
                    elements[elements.count-1] = newValue
                }
            }
        }

        func parserDidStartDocument(_ parser: XMLParser) {
            // the root document is simply an empty element name
            elements.append(XMLTree(elementName: ""))
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            // we do nothing her because we hold on to the root document
        }

        func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
        }


        func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) {
        }

        func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?) {
            //dbg("foundAttributeDeclarationWithName", attributeName, elementName, type, defaultValue)
        }

        func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
            //dbg("foundElementDeclarationWithName", elementName, model)
        }

        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        }

        func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            elements.append(XMLTree(elementName: elementName, attributes: attributeDict, children: [], namespaceURI: namespaceURI, qualifiedName: qName))
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if let element = elements.popLast() { // remove the last element…
                currentElement.children.append(.element(element)) // … and add it as a child to the parent
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentElement.children.append(.content(string))
        }

        func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
            currentElement.children.append(.whitespace(whitespaceString))
        }

        func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
            currentElement.children.append(.processingInstruction(target: target, data: data))
        }

        func parser(_ parser: XMLParser, foundComment comment: String) {
            currentElement.children.append(.comment(comment))
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            currentElement.children.append(.cdata(CDATABlock))
        }

        func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
            entityResolver(name, systemID)
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            parseErrors.append(parseError)
        }

        func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
            validationErrors.append(validationError)
        }
    }

//    public struct ParseError : Error, Hashable {
//        /// The line number in the original document at which the error occured
//        public var lineNumber: Int
//        /// The column number in the original document at which the error occured
//        public var columnNumber: Int
//        /// The underlying error code for the error
//        public var code: XMLParser.ErrorCode
//        /// Whether this is a validation error or a parser error
//        public var validation: Bool
//    }
}

@available(macOS 10.14, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private extension String {

    /// Returns the string with the given XML entites escaped; the default does not include single apostrophes
    func escapedXMLEntities(_ entities: XMLTree.Entity) -> String {
        var str = ""
        str.reserveCapacity(self.count)
        let lt = entities.contains(.lt)
        let amp = entities.contains(.amp)
        let gt = entities.contains(.gt)
        let quot = entities.contains(.quot)
        let apos = entities.contains(.apos)
        for char in self {
            switch char {
            case "<" where lt: str.append("&lt;")
            case "&" where amp: str.append("&amp;")
            case ">" where gt: str.append("&gt;")
            case "\"" where quot: str.append("&quot;")
            case "'" where apos: str.append("&apos;") // messes up CSS, and isn't necessary
            default: str.append(char)
            }
        }
        return str
    }
}

