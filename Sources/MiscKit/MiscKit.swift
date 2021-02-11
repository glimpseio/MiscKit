//  Marc Prud'hommeaux, 2014-20201

import Foundation

#if canImport(OSLog)
import OSLog
#endif

/// Logs the given items to `os_log` if `DEBUG` is set
/// - Parameters:
///   - level: the level: 0 for default, 1 for debug, 2 for info, 3 for error, 4+ for fault
@inlinable public func dbg(level: UInt8 = 0, _ arg1: @autoclosure () -> Any? = nil, _ arg2: @autoclosure () -> Any? = nil, _ arg3: @autoclosure () -> Any? = nil, _ arg4: @autoclosure () -> Any? = nil, _ arg5: @autoclosure () -> Any? = nil, _ arg6: @autoclosure () -> Any? = nil, _ arg7: @autoclosure () -> Any? = nil, _ arg8: @autoclosure () -> Any? = nil, _ arg9: @autoclosure () -> Any? = nil, _ arg10: @autoclosure () -> Any? = nil, _ arg11: @autoclosure () -> Any? = nil, _ arg12: @autoclosure () -> Any? = nil, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line) {
    let logit: Bool
    #if DEBUG
    logit = true
    #else
    logit = level > 1
    #endif

    if logit {
        let items = [arg1(), arg2(), arg3(), arg4(), arg5(), arg6(), arg7(), arg8(), arg9(), arg10(), arg11(), arg12()]
        let msg = items.compactMap({ $0 }).map(String.init(describing:)).joined(separator: " ")

        let funcName = functionName.description.split(separator: "(").first?.description ?? functionName.description

        // use just the last path component
        let filePath = fileName.description
            .split(separator: "/").last?.description
            .split(separator: ".").first?.description
            ?? fileName.description

        let message = "\(filePath):\(lineNumber) \(funcName): \(msg)"
        if #available(OSX 10.14, *) {
            #if canImport(OSLog)
            os_log(level == 0 ? .default : level == 1 ? .debug : level == 2 ? .info : level == 3 ? .error : .fault, "%{public}@", message)
            #else
            #endif
        } else {
            // other logging methods could go here
        }
    }
}

#if canImport(Darwin)
/// Returns the current nanoseconds (from an arbitrary base). This may be coarse or fine-grained, and is not guaranteed to be monotonically increasing.
@inlinable public func nanos() -> UInt64 {
    // mach_absolute_time() // don't use this, because it doesn't return nanoseconds under ARM
    // clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    // clock_gettime_nsec_np(CLOCK_UPTIME_RAW) // like “CLOCK_MONOTONIC_RAW, but that does not increment while the system is asleep”
    mach_approximate_time() // use the approximate time to save a few cycles
}
#endif

#if canImport(OSLog)
import OSLog
@available(OSX 10.14, *)
@usableFromInline let signpostLog = OSLog(subsystem: "net.misckit.MiscKit.prf", category: .pointsOfInterest)

/// Output a message with the amount of time the given block took to exeucte
/// - Parameter msg: the message prefix closure accepting the result of the `block`
/// - Parameter threshold: the threshold below which a message will not be printed
/// - Parameter functionName: the name of the calling function
/// - Parameter fileName: the fileName containg the calling function
/// - Parameter lineNumber: the line on which the function was called
/// - Parameter block: the block to execute
@available(OSX 10.14, *)
@inlinable public func prf<T>(_ message: @autoclosure () -> String = "", msg: (T) -> String = { _ in "" }, threshold: Double = -0.0, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, block: () throws -> T) rethrows -> T {
    //#if DEBUG
    os_signpost(.begin, log: signpostLog, name: functionName)
    defer { os_signpost(.end, log: signpostLog, name: functionName) }

    let start: UInt64 = nanos()
    let ret = try block()
    let end: UInt64 = max(nanos(), start)
    let secs = Double(end - start) / 1_000_000_000.0

    if secs >= threshold {
        let str = timeInMS(fromNanos: start, to: end)
        dbg(msg(ret), "time: \(str)", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }
    return ret
    //#else
    //return try block()
    //#endif
}
#endif


@inlinable public func timeInMS(_ from: CFAbsoluteTime, to: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> String {
    return "\(Int64(round((to - from) * 1000)))ms"
}

@inlinable public func timeInMS(fromDate from: Date, to: Date = Date()) -> String {
    timeInMS(from.timeIntervalSinceReferenceDate, to: to.timeIntervalSinceReferenceDate)
}

/// Returns a description of the number of nanoseconds that have elapsed between `from` and `to`.
/// - Parameters:
///   - fromNanos: the start time (typically obtained with `nanos()`)
///   - to: the end time, faulting to `nanos()`
@inlinable public func timeInMS(fromNanos from: UInt64, to: UInt64 = nanos()) -> String {

    let ms = Double(to - from) / 1_000_000
    if ms >= 1 {
        // round when over 1ms for formatting
        return "\(Int64(ceil(ms)))ms"
    } else {
        return "\(ms)ms"
    }
}

/// Localize the given string
@inlinable public func loc(_ msg: StaticString, comment: String = "") -> String {
    NSLocalizedString(msg.description, comment: comment)
}

/// Localize the given pattern
@inlinable public func locfmt(_ msg: StaticString, _ args: CVarArg...) -> String {
    // this works, but can be dangerous when a bad format specifier is used (e.g., %d with a string)
    String(format: loc(msg), locale: Locale.current, arguments: args)
}


/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
@discardableResult @inlinable public func wip<T>(_ value: T) -> T { value }
