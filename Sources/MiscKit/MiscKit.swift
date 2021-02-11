//  Marc Prud'hommeaux, 2014-20201

import Foundation

#if canImport(OSLog)
import OSLog
#endif

/// Logs the given items to `os_log` if `DEBUG` is set
/// - Parameters:
///   - level: the level: 0 for default, 1 for debug, 2 for info, 3 for error, 4+ for fault
@inlinable public func dbg(level: UInt8 = 0, _ arg1: @autoclosure () -> Any? = nil, _ arg2: @autoclosure () -> Any? = nil, _ arg3: @autoclosure () -> Any? = nil, _ arg4: @autoclosure () -> Any? = nil, _ arg5: @autoclosure () -> Any? = nil, _ arg6: @autoclosure () -> Any? = nil, _ arg7: @autoclosure () -> Any? = nil, _ arg8: @autoclosure () -> Any? = nil, _ arg9: @autoclosure () -> Any? = nil, _ arg10: @autoclosure () -> Any? = nil, _ arg11: @autoclosure () -> Any? = nil, _ arg12: @autoclosure () -> Any? = nil, functionName: StaticString = #function, fileName: StaticString = #file, lineNumber: Int = #line) {
    #if DEBUG
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
    #endif
}
