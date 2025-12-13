import Foundation
import SwiftyBeaver

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
