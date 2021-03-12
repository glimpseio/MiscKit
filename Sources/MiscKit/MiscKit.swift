// Various misc utilities
// Marc Prud'hommeaux, 2014-20201

import Foundation

/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
@discardableResult @inlinable public func wip<T>(_ value: T) -> T { value }


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

/// Function that merely executes a closure with the given initializer; useful for statically initializing let values while still enabling type inferrence.
@discardableResult @inlinable public func cfg<T>(_ value: @autoclosure () throws -> T, f: (inout T) throws -> ()) rethrows -> T {
    var v = try value()
    try f(&v)
    return v
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
@inlinable public func prf<T>(_ message: @autoclosure () -> String? = nil, msg messageBlock: ((T) -> String)? = nil, threshold: Double = -0.0, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, block: () throws -> T) rethrows -> T {
    //#if DEBUG

    let start: UInt64 = nanos()

    let result: T
    if #available(OSX 10.14, *) {
        os_signpost(.begin, log: signpostLog, name: functionName)
        defer { os_signpost(.end, log: signpostLog, name: functionName) }
        result = try block()
    } else {
        result = try block()
    }

    let end: UInt64 = max(nanos(), start)
    let secs = Double(end - start) / 1_000_000_000.0

    if secs >= threshold {
        let str = timeInMS(fromNanos: start, to: end)
        dbg(message(), messageBlock?(result), "time: \(str)", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }
    return result
    //#else
    //return try block()
    //#endif
}
#endif

#if canImport(Darwin)

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

#endif

/// Localize the given string
@inlinable public func loc(_ msg: StaticString, comment: StaticString = "") -> String {
    NSLocalizedString(msg.description, comment: comment.description)
}

/// Localize the given pattern
@inlinable public func locfmt(_ msg: StaticString, _ args: CVarArg..., comment: StaticString = "") -> String {
    // this works, but can be dangerous when a bad format specifier is used (e.g., %d with a string)
    String(format: loc(msg, comment: comment), locale: Locale.current, arguments: args)
}

#if canImport(Darwin)
/// The current total memory size.
/// Thanks, Quinn: https://developer.apple.com/forums/thread/105088
@inlinable public func memoryFootprint() -> mach_vm_size_t? {
    // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
    // complex for the Swift C importer, so we have to define them ourselves.
    let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
    var info = task_vm_info_data_t()
    var count = TASK_VM_INFO_COUNT
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
        }
    }
    guard
        kr == KERN_SUCCESS,
        count >= TASK_VM_INFO_REV1_COUNT
    else { return nil }
    return info.phys_footprint
}
#endif

#if canImport(Dispatch)
extension Collection {
    /// Executes the given block concurrently using `DispatchQueue.concurrentPerform`, returning the array of results
    /// - Note: this is the non-throwing form of `qmap`
    @inlinable public func qmap<T>(concurrent: Bool = true, block: (Element) -> (T)) -> [T] {
        let items = Array(self)
        var results: [T?] = Array(repeating: nil, count: items.count)

        let resultsLock = DispatchQueue(label: "resultsLock")
        DispatchQueue.concurrentPerform(iterations: items.count) { i in
            resultsLock.sync { results[i] = block(items[i]) }
        }

        return results.compactMap({ $0 })
    }

    /// Executes the given block concurrently using `DispatchQueue.concurrentPerform`, returning the array of results. If any of the blocks throws an error, the first error encountered will be thrown, but all the blocks will always be evaluated irrespective of whether any of them throw an error.
    /// - Note: this is the throwing form of `qmap`
    @inlinable public func qmap<T>(concurrent: Bool = true, block: (Element) throws -> (T)) throws -> [T] {
        let items = Array(self)
        var results: [Result<T, Error>?] = Array(repeating: nil, count: items.count)

        let resultsLock = DispatchQueue(label: "resultsLock")
        DispatchQueue.concurrentPerform(iterations: items.count) { i in
            let result = Result { try block(items[i]) }
            resultsLock.sync { results[i] = result }
        }

        // returns all the results, or throws the first error encountered
        // we can't use "rethrows" here, since we can't check at runtime whether any of the closures were throwing or not
        return try results.compactMap { try $0?.get() }
    }
}
#endif

/// fills in the given error pointer with the various parameters and returns the given value
/// - Parameters:
///   - args: The arguments that will be formatted into the description of the error
///   - failureReason: the title for the error that will be displayed in any Cocoa alerts (corresponding to `NSLocalizedFailureReasonErrorKey`)
///   - recoverySuggestion: the subtitle for the error that will be displayed in Cocoa alerts (corresponding to `NSLocalizedRecoverySuggestionErrorKey`)
///   - recoveryOptions: a list of possible recovery options
///   - underlyingError: a nested error
///   - trumpError: whether to override the error
public func err(_ args: Any..., title: String? = nil, subtitle recoverySuggestion: String? = nil, recoveryOptions : [String]? = nil, failureReason: String? = nil, error underlyingError: Error? = nil, trumpError: Bool = false, domain: String? = nil, code: Int = 0, url: URL? = nil, file: String? = nil, sourceFile: StaticString = #file, sourceLine: UInt = #line) -> NSError {

    var description = title ?? ""
    for arg in args {
        if !description.isEmpty { description += " " }
        description += String(describing: arg)
    }

    var info = [String:NSObject]()

    info[NSLocalizedDescriptionKey] = description as NSString

    if let recoverySuggestion = recoverySuggestion {
        info[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion as NSString
    }

    if let failureReason = failureReason {
        info[NSLocalizedFailureReasonErrorKey] = failureReason as NSString
    }

    if let recoveryOptions = recoveryOptions {
        info[NSLocalizedRecoveryOptionsErrorKey] = recoveryOptions as NSArray
    }

    if let url = url {
        info[NSURLErrorKey] = url as NSURL
    }

    if let file = file {
        info[NSFilePathErrorKey] = file as NSString
    }

    if let underlyingError = underlyingError {
        info[NSUnderlyingErrorKey] = underlyingError as NSError
        // we lose some non-NSError information when wrapping errors
        info[NSLocalizedFailureReasonErrorKey] = String(describing: underlyingError) as NSString
    }

    info["Source"] = ((String(describing: sourceFile) as NSString).lastPathComponent + ":" + String(sourceLine)) as NSString

    return NSError(domain: domain ?? ((String(describing: sourceFile) as NSString).lastPathComponent as NSString).deletingPathExtension, code: code, userInfo: info)
}

