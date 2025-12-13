import Foundation
import Gzip

/// Service for reading and exporting SwiftyBeaver logs
final class LogService {
  
  /// Default log file URL (SwiftyBeaver's FileDestination default location)
  private static var logFileURL: URL? {
    let fileManager = FileManager.default
    #if os(OSX)
      if let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
        if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String {
          let appURL = url.appendingPathComponent(appName, isDirectory: true)
          if fileManager.fileExists(atPath: appURL.path) {
            return appURL.appendingPathComponent("swiftybeaver.log", isDirectory: false)
          }
        }
        return url.appendingPathComponent("swiftybeaver.log", isDirectory: false)
      }
    #else
      if let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
        return url.appendingPathComponent("swiftybeaver.log", isDirectory: false)
      }
    #endif
    return nil
  }
  
  /// Read logs from SwiftyBeaver log file
  /// - Parameter since: Start date for log entries
  /// - Returns: Array of log entries as formatted strings
  static func readLogs(since: Date = Date().addingTimeInterval(-24 * 60 * 60)) -> [String] {
    guard let logURL = logFileURL, FileManager.default.fileExists(atPath: logURL.path) else {
      return []
    }
    
    do {
      let logContent = try String(contentsOf: logURL, encoding: .utf8)
      let lines = logContent.components(separatedBy: .newlines)
      
      let timeFormatter = DateFormatter()
      timeFormatter.dateFormat = "HH:mm:ss.SSS"
      
      let fullDateFormatter = DateFormatter()
      fullDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS Z"
      fullDateFormatter.timeZone = TimeZone.current
      
      // Get file modification date to use as base for reconstructing full dates
      let fileAttributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
      let fileModDate = (fileAttributes[.modificationDate] as? Date) ?? Date()
      let calendar = Calendar.current
      let fileDateComponents = calendar.dateComponents([.year, .month, .day], from: fileModDate)
      
      var filteredLogs: [(date: Date, line: String)] = []
      
      for line in lines {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
        
        // Parse log line format: "HH:mm:ss.SSS LEVEL File.Function:line - message context"
        // SwiftyBeaver format: "$DHH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M $X"
        
        let components = line.components(separatedBy: " ")
        guard components.count >= 4, let timeString = components.first, timeString.contains(":") else {
          // If line doesn't match expected format, try to include it with current date
          filteredLogs.append((date: Date(), line: line))
          continue
        }
        
        // Parse time component and reconstruct full date
        if let parsedTime = timeFormatter.date(from: timeString) {
          let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: parsedTime)
          
          var dateComponents = fileDateComponents
          dateComponents.hour = timeComponents.hour
          dateComponents.minute = timeComponents.minute
          dateComponents.second = timeComponents.second
          dateComponents.nanosecond = timeComponents.nanosecond
          
          if let fullDate = calendar.date(from: dateComponents), fullDate >= since {
            // Extract category from context if present
            let category = extractCategory(from: line)
            let level = extractLevel(from: line)
            let message = extractMessage(from: line)
            
            let formattedDate = fullDateFormatter.string(from: fullDate)
            let formattedLine = "[\(formattedDate)] [\(level)] [\(category)] \(message)"
            filteredLogs.append((date: fullDate, line: formattedLine))
          }
        }
      }
      
      // Sort by date (newest first) and return lines
      return filteredLogs.sorted { $0.date > $1.date }.map { $0.line }
    } catch {
      return ["Failed to read logs: \(error.localizedDescription)"]
    }
  }
  
  /// Extract category from log line context
  private static func extractCategory(from line: String) -> String {
    // Look for context JSON or key-value pairs
    // Context format in SwiftyBeaver: {"category":"network",...}
    if let contextRange = line.range(of: #"\{[^}]*"category"[^}]*\}"#, options: .regularExpression) {
      let contextString = String(line[contextRange])
      if let categoryRange = contextString.range(of: #""category"\s*:\s*"([^"]+)""#, options: .regularExpression) {
        let categoryMatch = String(contextString[categoryRange])
        if let category = categoryMatch.components(separatedBy: "\"").dropFirst().first {
          return category
        }
      }
    }
    return "default"
  }
  
  /// Extract log level from line
  private static func extractLevel(from line: String) -> String {
    let levelPatterns = [
      ("VERBOSE", "VERBOSE"),
      ("DEBUG", "DEBUG"),
      ("INFO", "INFO"),
      ("WARNING", "WARNING"),
      ("ERROR", "ERROR"),
      ("CRITICAL", "CRITICAL"),
      ("FAULT", "FAULT")
    ]
    
    for (pattern, level) in levelPatterns {
      if line.uppercased().contains(pattern) {
        return level
      }
    }
    
    // Check for emoji indicators
    if line.contains("🟩") { return "DEBUG" }
    if line.contains("🟦") { return "INFO" }
    if line.contains("🟨") { return "WARNING" }
    if line.contains("🟥") { return "ERROR" }
    if line.contains("⬜️") { return "VERBOSE" }
    
    return "INFO"
  }
  
  /// Extract message from log line
  private static func extractMessage(from line: String) -> String {
    // Format: "HH:mm:ss.SSS LEVEL File.Function:line - message context"
    // Extract everything after " - "
    if let messageRange = line.range(of: " - ") {
      let messagePart = String(line[messageRange.upperBound...])
      // Remove context JSON if present at the end
      if let contextRange = messagePart.range(of: #"\{[^}]*\}"#, options: .regularExpression, range: messagePart.range(of: messagePart)) {
        return String(messagePart[..<contextRange.lowerBound]).trimmingCharacters(in: .whitespaces)
      }
      return messagePart.trimmingCharacters(in: .whitespaces)
    }
    return line
  }
  
  /// Export logs to a file in tmp directory
  /// - Returns: URL of the exported log file, or nil if export failed
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
  
  /// Export logs as file (compressed if > 1MB)
  /// - Parameter since: Start date for log entries
  /// - Returns: URL of the exported file (txt or txt.gz), or nil if export failed
  static func exportLogsAsFile(since: Date = Date().addingTimeInterval(-24 * 60 * 60)) -> URL? {
    let logs = readLogs(since: since)
    
    guard !logs.isEmpty else {
      return nil
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss Z"
    let dateString = dateFormatter.string(from: Date())
    
    let logContent = logs.joined(separator: "\n")
    
    guard let inputData = logContent.data(using: .utf8) else {
      return nil
    }
    
    let tmpDir = FileManager.default.temporaryDirectory
    let oneMB = 1024 * 1024
    
    // If less than 1MB, export as plain text
    if inputData.count < oneMB {
      let txtFileName = "nschat_logs_\(dateString).txt"
      let txtFileURL = tmpDir.appendingPathComponent(txtFileName)
      
      do {
        try inputData.write(to: txtFileURL, options: .atomic)
        return txtFileURL
      } catch {
        return nil
      }
    } else {
      // Compress using GzipSwift if >= 1MB
      do {
        let compressedData = try inputData.gzipped()
        
        let gzipFileName = "nschat_logs_\(dateString).txt.gz"
        let gzipFileURL = tmpDir.appendingPathComponent(gzipFileName)
        
        try compressedData.write(to: gzipFileURL, options: .atomic)
        
        return gzipFileURL
      } catch {
        return nil
      }
    }
  }
}
