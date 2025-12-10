import SwiftUI
import SwiftData
import os

struct DangerZoneView: View {
  @Environment(\.modelContext) private var modelContext

  @State private var isDeleteAllChatsPresented = false
  @State private var isDeleteAllPromptsPresented = false
  @State private var isDeleteAllProvidersPresented = false
  @State private var isDeleteAllModelsPresented = false

  var body: some View {
    Form {
      Section {
        Button("Delete All Chats", systemImage: "trash", role: .destructive) {
          isDeleteAllChatsPresented.toggle()
        }
        .symbolRenderingMode(.multicolor)

        Button("Delete All Prompts", systemImage: "trash", role: .destructive) {
          isDeleteAllPromptsPresented.toggle()
        }
        .symbolRenderingMode(.multicolor)

        Button("Delete All Providers", systemImage: "trash", role: .destructive) {
          isDeleteAllProvidersPresented.toggle()
        }
        .symbolRenderingMode(.multicolor)
      }

      Section {
        Button("Remove Everything", systemImage: "trash", role: .destructive) {
          isDeleteAllModelsPresented.toggle()
        }
        .symbolRenderingMode(.multicolor)
      }
    }

    .confirmationDialog(
      "Delete All Chats?",
      isPresented: $isDeleteAllChatsPresented,
      titleVisibility: .visible
    ) {
      Button("Delete All Chats.", role: .destructive) {
        modelContext.clearAll(Chat.self)
      }
    }
    .confirmationDialog(
      "Delete All Prompts?",
      isPresented: $isDeleteAllPromptsPresented,
      titleVisibility: .visible
    ) {
      Button("Delete All Prompts", role: .destructive) {
        modelContext.clearAll(Prompt.self)
      }
    }
    .confirmationDialog(
      "Delete All Providers?",
      isPresented: $isDeleteAllProvidersPresented,
      titleVisibility: .visible
    ) {
      Button("Delete All Providers", role: .destructive) {
        modelContext.clearAll(Provider.self)
        AppLogger.data.info("Deleted all providers")
      }
    }
    .confirmationDialog(
      "Remove Everything?",
      isPresented: $isDeleteAllModelsPresented,
      titleVisibility: .visible
    ) {
      Button("Remove Everything", role: .destructive) {
        modelContext.clearAllModels()
        AppLogger.data.info("Deleted all SwiftData models")
      }
    }
    .navigationTitle("Danger Zone")
  }
}

#Preview {
  NavigationStack {
    DangerZoneView()
  }
}
