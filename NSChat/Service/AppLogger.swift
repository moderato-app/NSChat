import Foundation
import SwiftyBeaver

/// Privacy level for log entries (compatible with OSLog privacy parameter)
public enum Privacy {
  case `public`
  case `private`
  case sensitive
}

/// Wrapper for values with privacy marking
public struct PrivateValue {
  let value: Any
  let privacy: Privacy
  
  public init(_ value: Any, privacy: Privacy = .private) {
    self.value = value
    self.privacy = privacy
  }
  
  var description: String {
    switch privacy {
    case .public:
      return String(describing: value)
    case .private:
      return "<private>"
    case .sensitive:
      return maskSensitiveValue(String(describing: value))
    }
  }
  
  /// Mask sensitive value: show front and back, mask the middle half
  private func maskSensitiveValue(_ value: String) -> String {
    guard value.count > 2 else {
      // If length <= 2, show only first character
      if value.count == 1 {
        return "*"
      } else if value.count == 2 {
        return String(value.prefix(1)) + "*"
      }
      return "**"
    }
    // Show approximately 1/4 at front, mask middle 1/2, show 1/4 at back
    let frontCount = max(1, value.count / 4)
    let backCount = max(1, value.count / 4)
    let middleMaskCount = value.count - frontCount - backCount
    
    let frontPart = String(value.prefix(frontCount))
    let backPart = String(value.suffix(backCount))
    let middleMask = String(repeating: "*", count: middleMaskCount)
    
    return frontPart + middleMask + backPart
  }
}

/// Unified logging management system
/// Uses SwiftyBeaver for logging with emoji console output and file persistence
public final class AppLogger {
  
  // MARK: - Initialization
  
  private static var isInitialized = false
  
  /// Initialize SwiftyBeaver destinations
  private static func initializeIfNeeded() {
    guard !isInitialized else { return }
    
    // Console destination with emoji
    let console = ConsoleDestination()
    console.useTerminalColors = false // Use emoji instead of terminal colors
    console.format = "$DHH:mm:ss.SSS$d $C$L$c $N:$l $F - $M $X"
    SwiftyBeaver.addDestination(console)
    
    // File destination for persistence
    // Format includes context for category information: $DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M $X
    let file = FileDestination()
    file.format = "$DHH:mm:ss.SSS$d $C$L$c $N:$l $F - $M $X"
    SwiftyBeaver.addDestination(file)
    
    isInitialized = true
  }
  
  // MARK: - Category Logger
  
  /// Logger wrapper for a specific category
  public struct CategoryLogger {
    let category: String
    
    func verbose(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.verbose(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    func debug(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.debug(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    func info(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.info(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    func warning(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.warning(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    func error(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.error(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    func critical(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.critical(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    func fault(_ message: @autoclosure () -> Any, file: String = #file, function: String = #function, line: Int = #line, context: [String: Any]? = nil) {
      AppLogger.initializeIfNeeded()
      let mergedContext = mergeContext(context)
      SwiftyBeaver.fault(message(), file: file, function: function, line: line, context: mergedContext)
    }
    
    
    private func mergeContext(_ context: [String: Any]?) -> [String: Any] {
      let categoryContext: [String: Any] = ["category": category]
      guard let existingContext = context else {
        return categoryContext
      }
      return categoryContext.merging(existingContext) { (_, new) in new }
    }
  }
  
  // MARK: - Log Categories
  
  /// Network request related logs
  public static let network = CategoryLogger(category: "network")
  
  /// UI interaction related logs
  public static let ui = CategoryLogger(category: "ui")
  
  /// Data processing logs
  public static let data = CategoryLogger(category: "data")
  
  /// Error and exception logs
  public static let error = CategoryLogger(category: "error")
  
  /// Security and audit logs
  public static let audit = CategoryLogger(category: "audit")
  
  
  // MARK: - Structured Error Logging
  
  /// Structured error information
  public struct ErrorContext {
    let error: Error
    let operation: String       // Failed operation
    let component: String        // Component where error occurred
    let userMessage: String?     // User-friendly message (optional)
    let metadata: [String: Any]? // Additional metadata
  }
  
  /// Log structured error
  /// - Parameter context: Error context
  /// - Returns: Returns user-friendly error message
  @discardableResult
  public static func logError(_ context: ErrorContext) -> String {
    initializeIfNeeded()
    
    // Build error context dictionary
    var errorContext: [String: Any] = [
      "component": context.component,
      "operation": context.operation,
      "error": context.error.localizedDescription
    ]
    
    if let metadata = context.metadata {
      errorContext["metadata"] = metadata
    }
    
    // Internal debug information (full error)
    error.error("""
      [Error] Component:\(context.component) | \
      Operation:\(context.operation) | \
      Error:\(context.error.localizedDescription) | \
      Metadata:\(context.metadata?.description ?? "{}")
      """, context: errorContext)
    
    // Return sanitized user message
    return context.userMessage ?? "Operation failed, please try again later"
  }
  
  
  // MARK: - Convenience Methods
  
  /// Log network request start
  public static func logNetworkRequest(url: String, method: String = "GET") {
    network.info("📤 Network request [\(method)] \(url)")
  }
  
  /// Log network response
  public static func logNetworkResponse(url: String, statusCode: Int, duration: TimeInterval) {
    if (200..<300).contains(statusCode) {
      network.info("📥 Network response [\(statusCode)] \(url) - Duration: \(String(format: "%.3f", duration))s")
    } else {
      network.error("❌ Network error [\(statusCode)] \(url) - Duration: \(String(format: "%.3f", duration))s")
    }
  }
  
}

// MARK: - Extension: Convenient Error Context Builder

public extension AppLogger.ErrorContext {
  /// Quickly create error context from operation and error
  static func from(
    error: Error,
    operation: String,
    component: String,
    userMessage: String? = nil
  ) -> AppLogger.ErrorContext {
    return AppLogger.ErrorContext(
      error: error,
      operation: operation,
      component: component,
      userMessage: userMessage,
      metadata: nil
    )
  }
}

// MARK: - String Interpolation Extension for Privacy Support

extension String.StringInterpolation {
  /// Support for OSLog-style privacy parameter in string interpolation
  /// Usage: "Message: \(value, privacy: .private)"
  mutating func appendInterpolation<T>(_ value: T, privacy: Privacy) {
    switch privacy {
    case .public:
      appendInterpolation(value)
    case .private:
      appendLiteral("<private>")
    case .sensitive:
      let valueString = String(describing: value)
      appendLiteral(maskSensitiveValue(valueString))
    }
  }
  
  /// Support for OSLog-style privacy parameter with format
  /// Usage: "Duration: \(duration, format: .fixed(precision: 3), privacy: .public)"
  mutating func appendInterpolation<T>(_ value: T, format: StringFormat, privacy: Privacy = .public) {
    switch privacy {
    case .public:
      switch format {
      case .fixed(let precision):
        if let doubleValue = value as? Double {
          appendInterpolation(String(format: "%.\(precision)f", doubleValue))
        } else if let floatValue = value as? Float {
          appendInterpolation(String(format: "%.\(precision)f", floatValue))
        } else {
          appendInterpolation(value)
        }
      }
    case .private:
      appendLiteral("<private>")
    case .sensitive:
      let valueString = String(describing: value)
      appendLiteral(maskSensitiveValue(valueString))
    }
  }
  
  /// Mask sensitive value: show front and back, mask the middle half
  private func maskSensitiveValue(_ value: String) -> String {
    guard value.count > 2 else {
      // If length <= 2, show only first character
      if value.count == 1 {
        return "*"
      } else if value.count == 2 {
        return String(value.prefix(1)) + "*"
      }
      return "**"
    }
    // Show approximately 1/4 at front, mask middle 1/2, show 1/4 at back
    let frontCount = max(1, value.count / 4)
    let backCount = max(1, value.count / 4)
    let middleMaskCount = value.count - frontCount - backCount
    
    let frontPart = String(value.prefix(frontCount))
    let backPart = String(value.suffix(backCount))
    let middleMask = String(repeating: "*", count: middleMaskCount)
    
    return frontPart + middleMask + backPart
  }
}

/// Format options for string interpolation (compatible with OSLog)
public enum StringFormat {
  case fixed(precision: Int)
}
