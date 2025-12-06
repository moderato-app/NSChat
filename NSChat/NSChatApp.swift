import os
import SwiftData
import SwiftUI
import TipKit

let bundleName = Bundle.main.bundleIdentifier ?? "app.moderato.Chato.Chato"

@main
struct NSChat: App {
  init() {
    do {
      try Tips.configure()
    } catch {
      AppLogger.logError(.from(
        error: error,
        operation: "Configure Tips",
        component: "NSChat",
        userMessage: nil
      ))
    }
  }

  let container = ModelContainer.product()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .task {
          QueueService.shared.initialize(modelContainer: container)
        }
    }
    .modelContainer(container)
    #if os(macOS)
      .commands {
        SidebarCommands()
      }
    #endif
  }
}
