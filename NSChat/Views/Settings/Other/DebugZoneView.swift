import SwiftUI
import TipKit
import os

struct DebugZoneView: View {
  @Environment(\.modelContext) var modelContext
  @EnvironmentObject var pref: Pref

  var body: some View {
    Form {
      Section("") {
        Button("Reset User Defauts", systemImage: "arrow.clockwise") {
          pref.reset()
        }
        Button("Reset Tips", systemImage: "arrow.clockwise") {
          try? Tips.resetDatastore()
          try? Tips.configure()
        }
      }
      Section("Prompts") {
        Button("Fill Prompts", systemImage: "p.square") {
          do {
            try fillPrompts(modelContext, save: true)
          } catch {
            AppLogger.logError(.from(
              error: error,
              operation: "Fill prompts",
              component: "DebugZoneView",
              userMessage: "Failed to fill prompts"
            ))
          }
        }
        Button("Remove Preset Prompts", systemImage: "trash") {
          do {
            try modelContext.removePresetPrompts()
            try modelContext.save()
          } catch {
            AppLogger.logError(.from(
              error: error,
              operation: "Remove preset prompts",
              component: "DebugZoneView",
              userMessage: "Failed to remove preset prompts"
            ))
          }
        }
      }
    }
    .navigationTitle("Debug Zone")
  }
}

#Preview {
  NavigationStack {
    DebugZoneView()
  }
}
