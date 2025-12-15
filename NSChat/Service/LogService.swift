import Foundation
import Gzip

/// Service for reading and exporting SwiftyBeaver logs
enum LogService {
  /// Default log file URL (SwiftyBeaver's FileDestination default location)
  private static var logFileURL: URL? {
    let fileManager = FileManager.default
    if let url = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
      return url.appendingPathComponent("swiftybeaver.log", isDirectory: false)
    }
    return nil
  }

  /// Get all log file URLs (including rotated files)
  /// SwiftyBeaver rotates files as: swiftybeaver.log -> swiftybeaver.1.log -> swiftybeaver.2.log -> ...
  /// - Returns: Array of log file URLs, sorted by modification date (newest first)
  private static func getAllLogFileURLs() -> [URL] {
    guard let baseURL = logFileURL else { return [] }
    
    let fileManager = FileManager.default
    var logFiles: [(url: URL, modDate: Date)] = []
    
    // Add main log file
    if fileManager.fileExists(atPath: baseURL.path) {
      if let attr = try? fileManager.attributesOfItem(atPath: baseURL.path),
         let modDate = attr[.modificationDate] as? Date {
        logFiles.append((baseURL, modDate))
      }
    }
    
    // Find all rotated log files (swiftybeaver.1.log, swiftybeaver.2.log, ...)
    let baseFilename = baseURL.deletingPathExtension().lastPathComponent
    let fileExtension = baseURL.pathExtension
    let directory = baseURL.deletingLastPathComponent()
    
    // Try to find rotated files (index 1 to 100, reasonable limit)
    for index in 1...100 {
      let rotatedURL = directory
        .appendingPathComponent(baseFilename)
        .appendingPathExtension("\(index).\(fileExtension)")
      
      if fileManager.fileExists(atPath: rotatedURL.path) {
        if let attr = try? fileManager.attributesOfItem(atPath: rotatedURL.path),
           let modDate = attr[.modificationDate] as? Date {
          logFiles.append((rotatedURL, modDate))
        }
      } else {
        // If file doesn't exist, stop searching
        break
      }
    }
    
    // Sort by modification date (newest first)
    return logFiles.sorted { $0.modDate > $1.modDate }.map { $0.url }
  }

  /// Read logs from SwiftyBeaver log files (including rotated files)
  /// - Parameter since: Start date for log entries
  /// - Returns: Array of log entries as formatted strings (matching console format)
  static func readLogs(since: Date = Date().addingTimeInterval(-24 * 60 * 60)) -> [String] {
    let logURLs = getAllLogFileURLs()
    guard !logURLs.isEmpty else {
      return []
    }

    var allFilteredLogs: [(date: Date, line: String)] = []
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm:ss.SSS"
    let calendar = Calendar.current

    // Read all log files
    for logURL in logURLs {
      do {
        let logContent = try String(contentsOf: logURL, encoding: .utf8)
        let lines = logContent.components(separatedBy: .newlines)

        // Get file modification date to use as base for reconstructing full dates
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
        let fileModDate = (fileAttributes[.modificationDate] as? Date) ?? Date()
        let fileDateComponents = calendar.dateComponents([.year, .month, .day], from: fileModDate)

        for line in lines {
          guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

          // Parse log line format: "HH:mm:ss.SSS EMOJI LEVEL File:line Function - message context"
          // SwiftyBeaver format: "$DHH:mm:ss.SSS$d $C$L$c $N:$l $F - $M $X"
          // Example: "02:58:48.083 💚 DEBUG StoreKit:39 listenForTransactions() - listenForTransactions started... [\"category\": \"audit\"]"

          let components = line.components(separatedBy: " ")
          guard components.count >= 4, let timeString = components.first, timeString.contains(":")
          else {
            // If line doesn't match expected format, try to include it with file modification date
            allFilteredLogs.append((date: fileModDate, line: line))
            continue
          }

          // Parse time component and reconstruct full date
          if let parsedTime = timeFormatter.date(from: timeString) {
            let timeComponents = calendar.dateComponents(
              [.hour, .minute, .second, .nanosecond], from: parsedTime)

            var dateComponents = fileDateComponents
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            dateComponents.second = timeComponents.second
            dateComponents.nanosecond = timeComponents.nanosecond

            if let fullDate = calendar.date(from: dateComponents), fullDate >= since {
              // Keep original line format (matches console output)
              allFilteredLogs.append((date: fullDate, line: line))
            }
          }
        }
      } catch {
        // Continue reading other files even if one fails
        continue
      }
    }

    // Sort all logs by date (newest first) and return lines
    return allFilteredLogs.sorted { $0.date > $1.date }.map { $0.line }
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
