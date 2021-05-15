// Various misc utilities
// Marc Prud'hommeaux, 2014-2021

import Foundation

/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
@discardableResult @inlinable public func wip<T>(_ value: T) -> T { value }


/// The equivalent of `Sequence.reduce` for trees, including `IndexPath` to elements.
/// - Parameters:
///   - root: the root element of the tree
///   - initialResult: the initial result
///   - depthFirst: whether the traverse depth-first or breadth-first
///   - children: the closure to obtain children for a parent
///   - nextPartialResult: the reduction function; assigning false to the initial `keepGoing` field will halt evaluation and return the current result
/// - Throws: an error if either the `children` or `nextPartialResult` closures throw an error
/// - Returns: the result as constructed from a traversal of the tree up to the point that `nextPartialResult` returns `nil`
///
/// - SeeAlso: treeduceIndexed
@inlinable public func treeduce<T, U, C: Collection>(root: T, initialResult: U, depthFirst: Bool, children: (T) throws -> C, nextPartialResult: (inout Bool, U, T) throws -> U) rethrows -> U where C.Element == T {
    var pending = [root]
    var pendingCount = 1

    // beware attempts to simplify this; small changes can bring the `testTreePerformance` numbers up considerably. Current best-performance on the 8-level SplayTree test counts over 409_113 nodes is 15ms for an optimized build
    var result = initialResult
    while pendingCount > 0 {
        let node = pending.removeFirst()
        var keepGoing = true
        result = try nextPartialResult(&keepGoing, result, node)
        if keepGoing == false { return result } // the closure said to stop

        let childNodes = try children(node)
        let childCount = childNodes.count
        pendingCount = pendingCount + childCount - 1 // minus one for the removeFirst
        if childCount > 0 {
            pending.insert(contentsOf: childNodes, at: depthFirst ? pending.startIndex : pending.endIndex)
        }
    }

    return result
}


/// Maps each element of the tree with the given function
///
/// - Parameters:
///   - root: the root of the tree
///   - depthFirst: whether to traverse depthFirst (the default and the fastest) or breadth-first
///   - children: the closure for obtaining the child elements
///   - transform: the transform function to perform on each element
///
/// - Returns: the enumerated elements of the tree
/// - Throws: any error that the `children` or `transform` functions throw
/// - SeeAlso: treemapIndexed
@inlinable public func treemap<T, U, C: Collection>(root: T, depthFirst: Bool = true, children: (T) throws -> C, transform: (T) throws -> U) rethrows -> [U] where C.Element == T {
    try treeduce(root: root, initialResult: [], depthFirst: depthFirst, children: children) { _, array, element in
        array + [try transform(element)]
    }
}

/// Iterates through the tree and returns a count of all the elements
///
/// - Parameters:
///   - root: the root of the tree
///   - depthFirst: whether to traverse depthFirst (the default and the fastest) or breadth-first
///   - children: the closure for obtaining the child elements
/// - Returns: the total count of all the nodes in the tree
@inlinable public func treecount<T, C: Collection>(root: T, depthFirst: Bool = true, children: (T) -> C) -> Int where C.Element == T {
    // this could be implemented much less efficiently with the following:
    //return treegather(root: root, depthFirst: depthFirst, children: children).count
    treeduce(root: root, initialResult: 0, depthFirst: depthFirst, children: children, nextPartialResult: { _, count, _ in count + 1 })
}

/// Iterates through the tree and builds an array of all the nodes that pass the given `predicate` filter
///
/// - Parameters:
///   - root: the root of the tree
///   - depthFirst: whether to traverse depthFirst (the default and the fastest) or breadth-first
///   - children: the closure for obtaining the child elements
/// - Returns: all the elements of the tree
@inlinable public func treefilter<T, C: Collection>(root: T, depthFirst: Bool = true, children: (T) throws -> C, predicate: (T) throws -> Bool) rethrows -> [T] where C.Element == T {
    try treeduceIndexed(root: root, initialResult: [], depthFirst: depthFirst, children: children) { array, indexElement in
        try predicate(indexElement.1) ? array + [indexElement.1] : array
    }
}

/// Iterates through the tree and returns the first element that matches the given predicate
///
/// - Parameters:
///   - root: the root of the tree
///   - depthFirst: whether to traverse depthFirst (the default and the fastest) or breadth-first
///   - children: the closure for obtaining the child elements
///   - predicate: the predicate
/// - Returns: all the elements of the tree
@inlinable public func treefirst<T, C: Collection>(root: T, depthFirst: Bool = true, children: (T) throws -> C, predicate: (T) throws -> Bool) rethrows -> T? where C.Element == T {
    try treeduce(root: root, initialResult: T?.none, depthFirst: depthFirst, children: children) { keepGoing, result, element in
        if try predicate(element) == true {
            keepGoing = false // stop after the first match
            return element
        } else {
            return T?.none
        }
    }
}

// MARK: Indexed Tree

/// The equivalent of `Sequence.reduce` for trees, including `IndexPath` to elements.
/// - Parameters:
///   - root: the root element of the tree
///   - initialResult: the initial result
///   - depthFirst: whether the traverse depth-first or breadth-first
///   - children: the closure to obtain children for a parent
///   - nextPartialResult: the reduction function; returning nil will halt evaluation and return the current result
/// - Throws: an error if either the `children` or `nextPartialResult` closures throw an error
/// - Returns: the result as constructed from a traversal of the tree up to the point that `nextPartialResult` returns `nil`
///
/// - Note: if the `IndexPath` of the tree element is not needed, then it is more efficient to use `treeduce`, which doesn't incur the overhead of tracking the index of the current element
@inlinable public func treeduceIndexed<T, U, C: Collection>(root: T, initialResult: U, depthFirst: Bool, children: (T) throws -> C, nextPartialResult: (U, (IndexPath, T)) throws -> U?) rethrows -> U where C.Element == T {
    var pending = [(IndexPath(), root)]

    var result = initialResult
    while !pending.isEmpty {
        let (index, node) = pending.removeFirst()

        // returning nil from the transform indicates that we should end the traversal
        guard let nextResult = try nextPartialResult(result, (index, node)) else {
            return result
        }

        result = nextResult

        let indexedChildren = try children(node).enumerated().map { childIndex, childNode in
            (index.appending(childIndex), childNode)
        }

        if depthFirst {
            pending.insert(contentsOf: indexedChildren, at: pending.startIndex)
        } else {
            pending.append(contentsOf: indexedChildren)
        }
    }

    return result
}

/// Returns an enumeration of all the elements of the tree zipped with their `IndexPath` mapped over the given transform function.
///
/// - Parameters:
///   - root: the root of the tree
///   - depthFirst: whether to traverse depthFirst (the default and the fastest) or breadth-first
///   - children: the closure for obtaining the child elements
///   - transform: the transform function to perform on each element with its index
///
/// - Returns: the enumerated elements of the tree
/// - Throws: any error that the `children` or `transform` functions throw
/// - SeeAlso: treemap
@inlinable public func treemapIndexed<T, U, C: Collection>(root: T, depthFirst: Bool = true, children: (T) throws -> C, transform: (_ index: IndexPath, _ element: T) throws -> U) rethrows -> [U] where C.Element == T {
    try treeduceIndexed(root: root, initialResult: [], depthFirst: depthFirst, children: children) { array, indexElement in
        array + [try transform(indexElement.0, indexElement.1)]
    }
}

/// Returns an enumeration of all the elements of the tree zipped with their `IndexPath`.
///
/// - Parameters:
///   - root: the root of the tree
///   - depthFirst: whether to traverse depthFirst (the default and the fastest) or breadth-first
///   - children: the closure for obtaining the child elements
///
/// - Returns: the enumerated elements of the tree
@inlinable public func treenumerate<T, C: Collection>(root: T, depthFirst: Bool = true, children: (T) throws -> C) rethrows -> [(index: IndexPath, element: T)] where C.Element == T {
    try treemapIndexed(root: root, depthFirst: depthFirst, children: children) { index, element in
        (index: index, element: element)
    }
}



#if canImport(OSLog)
import OSLog
#endif

/// Logs the given items to `os_log` if `DEBUG` is set
/// - Parameters:
///   - level: the level: 0 for default, 1 for debug, 2 for info, 3 for error, 4+ for fault
@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
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
        #if canImport(OSLog)
        os_log(level == 0 ? .default : level == 1 ? .debug : level == 2 ? .info : level == 3 ? .error : .fault, "%{public}@", message)
        #else
        debugPrint(message) // fall back to good-old-fashioned printf
        #endif
    }
}

/// Function that merely executes a closure with the given initializer; useful for statically initializing let values while still enabling type inferrence.
@discardableResult @inlinable public func cfg<T>(_ value: @autoclosure () throws -> T, f: (inout T) throws -> ()) rethrows -> T {
    var v = try value()
    try f(&v)
    return v
}


// MARK: Timing Utilities

#if canImport(OSLog)
import OSLog

@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
@usableFromInline let signpostLog = OSLog(subsystem: "net.misckit.MiscKit.prf", category: .pointsOfInterest)
#endif

/// Output a message with the amount of time the given block took to exeucte
/// - Parameter message: the static message to log
/// - Parameter messageBlock: the dynamic message to log; the parameter to the closure is the result of the `block`
/// - Parameter level: the log level fot `dbg`
/// - Parameter threshold: the threshold below which a message will not be printed
/// - Parameter functionName: the name of the calling function
/// - Parameter fileName: the fileName containg the calling function
/// - Parameter lineNumber: the line on which the function was called
/// - Parameter block: the block to execute
@available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
@inlinable public func prf<T>(_ message: @autoclosure () -> String? = nil, msg messageBlock: ((T) -> String)? = nil, level: UInt8 = 0, threshold: Double = -0.0, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line, block: () throws -> T) rethrows -> T {
    //#if DEBUG

    let start: UInt64 = nanos()

    #if canImport(OSLog)
    os_signpost(.begin, log: signpostLog, name: functionName)
    defer { os_signpost(.end, log: signpostLog, name: functionName) }
    #endif

    let result = try block()

    let end: UInt64 = max(nanos(), start)
    let secs = Double(end - start) / 1_000_000_000.0

    if secs >= threshold {
        let timeStr = timeInMS(fromNanos: start, to: end)

        dbg(level: level, message(), messageBlock?(result), "time: \(timeStr)", functionName: functionName, fileName: fileName, lineNumber: lineNumber)
    }
    return result
}



@inlinable public func timeInMS(_ from: Double, to: Double = Date().timeIntervalSinceReferenceDate) -> String {
    return "\(Int64(round((to - from) * 1000)))ms"
}

@inlinable public func timeInMS(fromDate from: Date, to: Date = Date()) -> String {
    timeInMS(from.timeIntervalSinceReferenceDate, to: to.timeIntervalSinceReferenceDate)
}

#if canImport(Dispatch)
/// Returns the current nanoseconds (from an arbitrary base). This may be coarse or fine-grained, and is not guaranteed to be monotonically increasing.
@inlinable public func nanos() -> UInt64 {
    // mach_absolute_time() // don't use this, because it doesn't return nanoseconds under ARM
    // clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    // clock_gettime_nsec_np(CLOCK_UPTIME_RAW) // like “CLOCK_MONOTONIC_RAW, but that does not increment while the system is asleep”
    //mach_approximate_time() // use the approximate time to save a few cycles
    DispatchTime.now().uptimeNanoseconds
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

extension Sequence {
    /// Returns this sequence sorted by the given keypath of the element, either
    /// forwards (the default) or backwards.
    @inlinable public func sorting<T: Comparable>(by keyPath: KeyPath<Element, T>, forward: Bool = true) -> [Element] {
        sorted(by: { forward ? ($0[keyPath: keyPath] < $1[keyPath: keyPath]) : ($0[keyPath: keyPath] > $1[keyPath: keyPath]) })
    }
}

extension Collection where Self.Index : Strideable {
    /// Sub-divide the given collection into sub-collections
    @inlinable public func subdivided(into size: Index.Stride) -> [SubSequence] {
        stride(from: startIndex, to: endIndex, by: size).map { i in
            self[i..<Swift.min(i.advanced(by: size), endIndex)]
        }
    }
}


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


public extension DispatchQueue {
    /// If the current thread is main than execute the given code imediately;
    /// otherwise queue it for async execution
    @inlinable static func mainOrAsync(_ f: @escaping () -> ()) {
        if Thread.isMainThread {
            f()
        } else {
            DispatchQueue.main.async(execute: f)
        }
    }

    /// Issues an `asyncAfter`, cancelling any `reschedule` work item and replacing it with the new one.
    /// This can be used for debouncing multiple requests into only the final one.
    ///
    /// Note that this does not guarantee that the outstanding `reschedule` work item
    /// will not be completed, since it may have already executed or currently be executing
    /// when this call is performed.
    ///
    /// - Parameter deadline: the time after which the work item should be executed, given as a `DispatchTime`.
    /// - Parameter reschedule: the work item to cancel (if non-empty) and replace with the newly created item.
    /// - Parameter execute: The work item to be invoked on the queue.
    ///
    /// - SeeAlso: `async(execute:)`
    /// - SeeAlso: `asyncAfter(deadline:execute:)`
    /// - SeeAlso: `DispatchQoS`
    /// - SeeAlso: `DispatchWorkItemFlags`
    /// - SeeAlso: `DispatchTime`
    @inlinable func asyncAfter(deadline: DispatchTime? = nil, reschedule workItem: inout DispatchWorkItem?, execute block: @escaping () -> Void) {
        if let workItem = workItem, !workItem.isCancelled {
            workItem.cancel()
        }
        let item = DispatchWorkItem(block: block)
        if let deadline = deadline {
            self.asyncAfter(deadline: deadline, execute: item)
        } else {
            self.async(execute: item)
        }
        workItem = item // update the replacing item
    }
}


/// A pool of potentially-expensive resources that will be created on-demand in a thread-safe way.
/// Pools can be configured to shrink down to a `preferredPoolSize` after a `poolShrinkDelay`.
public class Pool<T> {
    public var preferredPoolSize: Int?

    /// The amount of time to wait after the last borrow before we shrink the pool
    public var poolShrinkDelay: TimeInterval = 9.0 // seconds

    /// The queue for synchronizing access to the pooled values
    let lockQueue = DispatchQueue(label: "lockQueue")

    /// The pool of objects
    var pool: [T] = []

    /// The number of elements in the pool
    public var count: Int { return lockQueue.sync { pool.count } }

    /// The dispatch item for shrinking the queue
    private var shrinkWork: DispatchWorkItem? = nil

    private let shrinkWorkLock = DispatchQueue(label: "shrinkWorkLock")

    public init() { }

    /// Returns the size of the pool
    public var size: Int {
        return lockQueue.sync { pool.count }
    }

    /// Borrow a resource, returning it after the block is executed. If the pool is currently empty, a new instance will be created and then returned to the pool once the block is complete.
    public func borrowing<U>(borrower: () throws -> T, _ f: (T) throws -> U) rethrows -> U {
        var last: T?
        lockQueue.sync { last = pool.popLast() }
        //dbg("borrow from", Thread.current)
        let resource = try last ?? borrower()
        defer {
            //dbg(Pool.self, "borrowing", last == nil ? "new" : "pooled", "item", pool.count)

            // …then issue a shrink after a delay
            if let preferredPoolSize = preferredPoolSize {
                scheduleShrinkTimer(to: preferredPoolSize)
            }

            lockQueue.sync {
//                if pool.count > ProcessInfo.processInfo.activeProcessorCount {
//                    // debugging why the pool would ever grow beyond the number of cores
//                    dbg("pool too big", pool.count)
//                }
                pool.append(resource)
            }
        }
        return try f(resource)
    }

    func scheduleShrinkTimer(to size: Int) {
        let currentSize = lockQueue.sync { self.pool.count }
        if currentSize <= size { return }

        shrinkWorkLock.sync {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + poolShrinkDelay, reschedule: &shrinkWork) { [weak self] in
                self?.shrink(to: currentSize - 1)
                self?.scheduleShrinkTimer(to: size) // continue shriking
            }
        }
    }

    /// Shrink the pool down to the given size
    public func shrink(to size: Int) {
        lockQueue.sync {
            let poolCount = pool.count
            let remove = poolCount - size
            if remove > 0 {
                // checking the memory would be nice, but expensive pool objects like JSContext seem to take a little while before their memory cleanup becomes visible
                //let preMemory = currentMemoryMB() ?? 0
                pool.removeLast(remove)
                //let postMemory = currentMemoryMB() ?? 0
                //dbg(Pool.self, "shrunk pool from", poolCount, "→", pool.count) // , (postMemory - preMemory))
            }
        }
    }

    /// Remove all elements of the pool
    public func clear() {
        self.shrink(to: 0)
    }
}
