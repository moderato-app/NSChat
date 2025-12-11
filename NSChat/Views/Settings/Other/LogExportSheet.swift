import os
import SwiftUI

fileprivate let maxLogEntriesToShow = 500

enum LogTimeRange: String, CaseIterable, Identifiable {
  case none = "None"
  case tenMinutes = "10 minutes"
  case thirtyMinutes = "30 minutes"
  case oneHour = "1 hour"
  case threeHours = "3 hours"
  case sixHours = "6 hours"
  case twelveHours = "12 hours"
  case twentyFourHours = "24 hours"
  
  var id: String { rawValue }
  
  var timeInterval: TimeInterval? {
    switch self {
    case .none:
      return nil
    case .tenMinutes:
      return 10 * 60
    case .thirtyMinutes:
      return 30 * 60
    case .oneHour:
      return 60 * 60
    case .threeHours:
      return 3 * 60 * 60
    case .sixHours:
      return 6 * 60 * 60
    case .twelveHours:
      return 12 * 60 * 60
    case .twentyFourHours:
      return 24 * 60 * 60
    }
  }
}

struct LogExportSheet: View {
  @Environment(\.dismiss) var dismiss
  @State private var selectedRange: LogTimeRange = .none
  @State private var logs: [String] = []
  @State private var isLoadingLogs = false
  @State private var isExporting = false
  @State private var showMailComposer = false
  @State private var mailData: MailData?
  @State private var showError = false
  @State private var errorMessage = ""
  
  var body: some View {
    NavigationView {
      List {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Select the time range of logs to export")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            
            Text("Logs will be attached to an email sent to the developer")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
          
          Picker("Time Range", selection: $selectedRange) {
            ForEach(LogTimeRange.allCases) { range in
              Text(range.rawValue).tag(range)
            }
          }
          .pickerStyle(.menu)
        }
        .textCase(.none)

        preview
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Email") {
            exportAndSendEmail()
          }
          .disabled(isExporting || isLoadingLogs)
        }
      }
      .onChange(of: selectedRange) { _, newValue in
        if newValue != .none {
          loadLogs(for: newValue)
        } else {
          logs = []
        }
      }
      .sheet(isPresented: $showMailComposer) {
        if let mailData = mailData {
          MailComposeView(mailData: mailData)
        }
      }
      .alert("Export Failed", isPresented: $showError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
    }
  }
  
  @ViewBuilder
  private var preview: some View {
    if isLoadingLogs {
      Section {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
        .padding()
      }
    } else if !logs.isEmpty {
      Section {
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(logs.prefix(maxLogEntriesToShow).enumerated()), id: \.offset) { _, log in
              Text(log)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
            }
            
            if logs.count > maxLogEntriesToShow {
              Text("... and \(logs.count - maxLogEntriesToShow) more entries")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      } header: {
        Text("Log Preview")
      } footer: {
        Text("Showing \(min(logs.count, maxLogEntriesToShow)) of \(logs.count) log entries")
      }
      .textCase(.none)
    }
  }
  
  private func loadLogs(for range: LogTimeRange) {
    guard let timeInterval = range.timeInterval else {
      logs = []
      return
    }
    
    isLoadingLogs = true
    DispatchQueue.global(qos: .userInitiated).async {
      let since = Date().addingTimeInterval(-timeInterval)
      let loadedLogs = LogService.readLogs(since: since)
      
      DispatchQueue.main.async {
        self.logs = loadedLogs
        self.isLoadingLogs = false
      }
    }
  }
  
  private func exportAndSendEmail() {
    isExporting = true
    
    // If no time range is selected, send email without attachment
    if selectedRange == .none {
      let deviceInfo = generateDeviceInfo()
      isExporting = false
      mailData = MailData(
        subject: "NSChat Support",
        recipients: ["support@moderato.app"],
        body: deviceInfo,
        attachmentURL: nil,
        attachmentMimeType: nil
      )
      showMailComposer = true
      return
    }
    
    // Otherwise, export logs and attach to email
    DispatchQueue.global(qos: .userInitiated).async {
      let since: Date
      if let timeInterval = selectedRange.timeInterval {
        since = Date().addingTimeInterval(-timeInterval)
      } else {
        // Fallback
        since = Date().addingTimeInterval(-24 * 60 * 60)
      }
      
      if let fileURL = LogService.exportLogsAsFile(since: since) {
        let isGzipped = fileURL.pathExtension == "gz"
        let mimeType = isGzipped ? "application/gzip" : "text/plain"
        let deviceInfo = self.generateDeviceInfo()
        
        DispatchQueue.main.async {
          self.isExporting = false
          self.mailData = MailData(
            subject: "NSChat Support - Logs Attached",
            recipients: ["support@moderato.app"],
            body: deviceInfo,
            attachmentURL: fileURL,
            attachmentMimeType: mimeType
          )
          self.showMailComposer = true
        }
      } else {
        DispatchQueue.main.async {
          self.isExporting = false
          self.errorMessage = "Failed to export logs. Please try again."
          self.showError = true
        }
      }
    }
  }
  
  private func generateDeviceInfo() -> String {
    let device = UIDevice.current
    let systemVersion = device.systemVersion
    let deviceModel = device.model
    let deviceName = device.name
    
    // Get more specific device model
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0)
      }
    }
    
    // Get app version
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    // Get screen info
    let screen = UIScreen.main
    let screenSize = screen.bounds.size
    let scale = screen.scale
    
    var info = """
    Please describe the issue here:
    
    
    
    ────────────────────────────────
    Device Information:
    ────────────────────────────────
    Device Model: \(deviceModel)
    Device Name: \(deviceName)
    Model Code: \(modelCode ?? "Unknown")
    System Version: iOS \(systemVersion)
    
    App Version: \(appVersion) (\(buildNumber))
    
    Screen Size: \(Int(screenSize.width))×\(Int(screenSize.height))
    Screen Scale: \(scale)x
    """
    
    // Only include log info if a time range is selected
    if selectedRange != .none {
      info += """
      
      
      Time Range: \(selectedRange.rawValue)
      Log Count: \(logs.count) entries
      """
    }
    
    return info
  }
}

struct MailData {
  let subject: String
  let recipients: [String]
  let body: String?
  let attachmentURL: URL?
  let attachmentMimeType: String?
}

#Preview {
  LogExportSheet()
}
