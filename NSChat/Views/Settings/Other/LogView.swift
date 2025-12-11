import SwiftUI
import os

struct LogView: View {
  @State private var logs: [String] = []
  @State private var isLoadingLogs = false
  @State private var isExporting = false
  @State private var exportURL: URL?
  @State private var showShareSheet = false
  @State private var showError = false
  @State private var errorMessage = ""
  
  var body: some View {
    List {
      Section {
        Button {
          loadLogs()
        } label: {
          Label {
            Text("Refresh Logs")
              .tint(.primary)
          } icon: {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(isLoadingLogs)
        
        Button {
          exportLogs()
        } label: {
          Label {
            Text(isExporting ? "Exporting..." : "Export Logs")
              .tint(.primary)
          } icon: {
            if isExporting {
              ProgressView()
            } else {
              Image(systemName: "square.and.arrow.up")
            }
          }
        }
        .disabled(isLoadingLogs || isExporting || logs.isEmpty)
      } header: {
        Text("Actions")
      }
      .textCase(.none)
      
      if isLoadingLogs {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .padding()
        }
      } else if logs.isEmpty {
        Section {
          Text("No logs available")
            .foregroundStyle(.secondary)
            .padding()
        } header: {
          Text("Logs")
        }
        .textCase(.none)
      } else {
        Section {
          ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
            Text(log)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .padding(.vertical, 4)
          }
        } header: {
          Text("Logs")
        } footer: {
          Text("Showing \(logs.count) log entries")
        }
        .textCase(.none)
      }
    }
    .navigationTitle("Logs")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      loadLogs()
    }
    .sheet(isPresented: $showShareSheet) {
      if let exportURL = exportURL {
        ShareSheet(items: [exportURL])
      }
    }
    .alert("Export Failed", isPresented: $showError) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(errorMessage)
    }
  }
  
  private func loadLogs() {
    isLoadingLogs = true
    DispatchQueue.global(qos: .userInitiated).async {
      let loadedLogs = LogService.readLogs()
      DispatchQueue.main.async {
        self.logs = loadedLogs
        self.isLoadingLogs = false
      }
    }
  }
  
  private func exportLogs() {
    isExporting = true
    DispatchQueue.global(qos: .userInitiated).async {
      if let url = LogService.exportLogs() {
        DispatchQueue.main.async {
          self.exportURL = url
          self.isExporting = false
          self.showShareSheet = true
        }
      } else {
        DispatchQueue.main.async {
          self.isExporting = false
          self.errorMessage = "Failed to export logs"
          self.showError = true
        }
      }
    }
  }
}

#Preview {
  NavigationView {
    LogView()
  }
}
