import Foundation
import OSLog
import os

/// Service for reading and exporting OSLog logs
final class LogService {
  
  private static let subsystem = bundleName
  
  /// Read logs from OSLogStore
  /// - Parameter since: Start date for log entries
  /// - Returns: Array of log entries as formatted strings
  @available(iOS 15.0, *)
  static func readLogs(since: Date = Date().addingTimeInterval(-24 * 60 * 60)) -> [String] {
    do {
      let logStore = try OSLogStore(scope: .currentProcessIdentifier)
      let position = logStore.position(date: since)
      
      let allEntries = try logStore.getEntries(at: position)
      let logEntries = allEntries.compactMap { $0 as? OSLogEntryLog }
        .filter { $0.subsystem == subsystem }
        .sorted { $0.date > $1.date }
      
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
      dateFormatter.timeZone = TimeZone.current
      
      return logEntries.map { entry in
        let dateString = dateFormatter.string(from: entry.date)
        let level = logLevelString(entry.level)
        let category = entry.category.isEmpty ? "default" : entry.category
        return "[\(dateString)] [\(level)] [\(category)] \(entry.composedMessage)"
      }
    } catch {
      return ["Failed to read logs: \(error.localizedDescription)"]
    }
  }
  
  /// Export logs to a file in tmp directory
  /// - Returns: URL of the exported log file, or nil if export failed
  @available(iOS 15.0, *)
  static func exportLogs() -> URL? {
    let logs = readLogs(since: Date().addingTimeInterval(-7 * 24 * 60 * 60))
    
    guard !logs.isEmpty else {
      return nil
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let dateString = dateFormatter.string(from: Date())
    
    let fileName = "nschat_logs_\(dateString).txt"
    let tmpDir = FileManager.default.temporaryDirectory
    let fileURL = tmpDir.appendingPathComponent(fileName)
    
    let logContent = logs.joined(separator: "\n")
    
    do {
      try logContent.write(to: fileURL, atomically: true, encoding: .utf8)
      return fileURL
    } catch {
      return nil
    }
  }
  
  @available(iOS 15.0, *)
  private static func logLevelString(_ level: OSLogEntryLog.Level) -> String {
    switch level {
    case .undefined:
      return "UNDEF"
    case .debug:
      return "DEBUG"
    case .info:
      return "INFO"
    case .notice:
      return "NOTICE"
    case .error:
      return "ERROR"
    case .fault:
      return "FAULT"
    @unknown default:
      return "UNKNOWN"
    }
  }
}
