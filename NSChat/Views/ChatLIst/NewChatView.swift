import SwiftData
import SwiftUI

struct NewChatView: View {
  @Environment(\.modelContext) var modelContext
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var pref: Pref
  @State var chatName = ""
  @State var chatOption: ChatOption = .init()
  @FocusState private var isFocused: Bool
  @State private var triggerHaptic: Bool = false
  @Query(sort: \UsedModel.createdAt) private var usedModels: [UsedModel]

  private var chatNamePlaceHolder: String {
    if let prompt = chatOption.prompt {
      prompt.name
    } else {
      "New Chat at " + Date.now.formatted(date: .omitted, time: .shortened)
    }
  }

  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    NavigationStack {
      Form {
        Section("Name") {
          TextField(chatNamePlaceHolder, text: $chatName)
            .focused($isFocused)
        }.textCase(.none)

        Section("General") {
          ChatOptionView(chatOption)
        }.textCase(.none)
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            if chatName.isMeaningless {
              chatName = chatNamePlaceHolder
            }

            if let model = chatOption.model {
              modelContext.insert(UsedModel(model: model))
            }

            dismiss()
            triggerHaptic.toggle()
            // chat list animation conflicts with dismiss()
            // do it a little bit later
            Task.detached {
              try await Task.sleep(for: .seconds(0.1))
              Task { @MainActor in
                modelContext.insert(Chat(name: chatName, option: chatOption))
              }
            }
          }
          .softFeedback(triggerHaptic)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .navigationTitle("New Chat")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: Prompt.self) { PromptEditorView($0) }
      .navigationDestination(for: String.self) { str in
        switch str {
        case NavigationRoute.promptList:
          PromptListView(chatOption: chatOption)
        case NavigationRoute.newPrompt:
          PromptCreateView { _ in }
        case NavigationRoute.modelSelection:
          ModelSelectionView(chatOption: chatOption)
        default:
          Text("navigationDestination not found for string: \(str)")
        }
      }
      .onAppear {
        load()
      }
    }
  }

  func load() {
    chatOption.model = usedModels.first?.model
    chatOption.historyCount = pref.newChatPrefHistoryMessageCount
    chatOption.webSearchOption?.contextSize = pref.newChatPrefWebSearchContextSize
  }
}

#Preview {
  ModelContainerPreview(ModelContainer.preview) {
    NavigationStack {
      NewChatView()
    }
  }
}
