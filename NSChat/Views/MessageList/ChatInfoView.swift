import SwiftData
import SwiftUI

struct ChatInfoView: View {
  @EnvironmentObject var em: EM
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @FocusState private var isFocused: Bool
  @State private var isClearHistoryPresented = false

  @Bindable var chat: Chat
  @State private var chatNamePlaceHolder: String = ""
  @State private var isGeneratingTitle = false

  var body: some View {
    // let _ = Self.printChagesWhenDebug()
    NavigationStack {
      Form {
        Section {
          TextField(chatNamePlaceHolder, text: $chat.name)
            .focused($isFocused)
        } header: {
          HStack {
            Text("Chat Name")
            Spacer()
            if isGeneratingTitle {
              ProgressView()
                .scaleEffect(0.8)
            } else {
              Button {
                isGeneratingTitle = true
                TitleGenerationService.shared.generateTitleManually(
                  chat: chat,
                  modelContext: modelContext,
                  onStart: {
                    isGeneratingTitle = true
                  },
                  onComplete: {
                    isGeneratingTitle = false
                  }
                )
              } label: {
                Image(systemName: "arrow.clockwise")
              }
              .font(.caption)
              .disabled(chat.option.model == nil || chat.messages.isEmpty)
            }
          }
        }
        .textCase(.none)

        Section("General") {
          ChatOptionView(chat.option)
        }.textCase(.none)

        if let pro = chat.option.model?.provider,
           pro.type.isWebSearchAvailable,
           let wso = chat.option.webSearchOption
        {
          Section("Web Search") {
            WebSearchOptionView(webSearch: wso)
          }
          .textCase(.none)
        }

        Section("Parameters") {
          ChatAdvancedOptionView(chat.option)
        }
        .textCase(.none)

        Section {
          Button(role: .destructive) {
            isClearHistoryPresented = true
          } label: {
            Label("Clear Messages", systemImage: "paintbrush")
              .foregroundColor(chat.messages.isEmpty ? .secondary : .red)
          }
          .disabled(chat.messages.isEmpty)
        }.textCase(.none)
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            if chat.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              chat.name = chatNamePlaceHolder
            }
            dismiss()
          }
        }
      }
      .confirmationDialog("Clear Messages?",
                          isPresented: $isClearHistoryPresented,
                          titleVisibility: .visible)
      {
        Button("Clear", role: .destructive) {
          clearMessages()
        }
      } message: {
        Text("All messages in this chat will be cleared.")
      }
      .onAppear {
        self.chatNamePlaceHolder = chat.name
      }
      .onDisappear {
        let newName = chat.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if newName.isEmpty {
          chat.name = chatNamePlaceHolder
        } else {
          chat.name = newName
        }
        em.chatOptionChanged.send()
      }
      .navigationTitle("Chat Info")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: Prompt.self) { PromptEditorView($0) }
      .navigationDestination(for: String.self) { str in
        switch str {
        case NavigationRoute.promptList:
          PromptListView(chatOption: chat.option)
        case NavigationRoute.newPrompt:
          PromptCreateView { _ in }
        case NavigationRoute.modelSelection:
          ModelSelectionView(chatOption: chat.option)
        default:
          Text("navigationDestination not found for string: \(str)")
        }
      }
    }
  }

  private func clearMessages() {
    for m in chat.messages {
      modelContext.delete(m)
    }
    em.messageEvent.send(.countChanged)
  }
}

#Preview {
  LovelyPreview {
    ChatInfoView(chat: ChatSample.manyMessages)
  }
}
