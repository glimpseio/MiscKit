/// RichString  is a partial back-port of `Foundation.AttributedString` for pre-5.5 releases.

import Foundation


#if canImport(TabularData) // as a proxy for @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias RichStringBase = Foundation.AttributedStringProtocol
#else
public typealias RichStringBase = CustomStringConvertible & Hashable
#endif

/// A string with formatting.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public protocol RichStringProtocol : RichStringBase {
    associatedtype Index
    associatedtype UnicodeScalarView

    var startIndex: Index { get }
    var endIndex: Index { get }
    var unicodeScalars: UnicodeScalarView { get }
}

#if canImport(TabularData)
/// A rich string.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias RichString = Foundation.AttributedString

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension RichString : RichStringProtocol {
    // conforms via `Foundation.AttributedString`
}
#else

/// Stopgap implementation of `AttributedString`
///
@available(*, deprecated, renamed: "RichString")
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias AttributedString = RichString

/// A rich string.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public typealias RichString = RawRichString

/// A type that confroms to `AttributedStringProtocol` with raw text.
/// Formatting is not supported.
@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
public struct RawRichString: RichStringProtocol, RawRepresentable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public typealias Storage = Swift.String
    public typealias Index = Storage.Index
    public typealias UnicodeScalarView = Storage.UnicodeScalarView

    public var startIndex: RichString.Index { rawValue.startIndex }
    public var endIndex: RichString.Index { rawValue.endIndex }
    public var unicodeScalars: RichString.UnicodeScalarView { rawValue.unicodeScalars }

    public var description: String { rawValue }
}

#endif
