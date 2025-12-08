import SwiftData
import SwiftUI

// MARK: - ChatDetailView

struct ChatDetailView: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.modelContext) private var modelContext
  @EnvironmentObject private var em: EM
  @EnvironmentObject private var pref: Pref

  @State private var isInfoPresented = false
  @State private var isPromptPresented = false
  @State private var isSettingPresented = false

  let chat: Chat

  var body: some View {
    ChatDetailRepresentable(
      chat: chat,
      em: em,
      pref: pref,
      modelContext: modelContext,
      onPresentInfo: { isInfoPresented = true },
      onPresentPrompt: { isPromptPresented = true }
    )
    .ignoresSafeArea(.keyboard)
    .toolbarBackground(.hidden, for: .automatic)
    .toolbar {
      ToolbarTitleMenu {
        Section {
          Button {
            isSettingPresented.toggle()
          } label: {
            HStack {
              Text("Settings")
              Image(systemName: "gear")
            }
          }
        }
      }
    }
    .sheet(isPresented: $isInfoPresented) {
      ChatInfoView(chat: chat)
        .presentationDetents([.large])
    }
    .sheet(isPresented: $isPromptPresented) {
      NavigationStack {
        if let p = chat.option.prompt {
          PromptEditorView(p)
            .toolbar { Button("OK") { isPromptPresented.toggle() } }
        } else {
          PromptCreateView { p in
            chat.option.prompt = p
          }
        }
      }
      .presentationDetents([.large])
    }
    .sheet(isPresented: $isSettingPresented) {
      SettingView()
        .preferredColorScheme(colorScheme)
        .presentationDetents([.large])
    }
  }
}

// MARK: - ChatDetailRepresentable

struct ChatDetailRepresentable: UIViewControllerRepresentable {
  let chat: Chat
  let em: EM
  let pref: Pref
  let modelContext: ModelContext
  let onPresentInfo: () -> Void
  let onPresentPrompt: () -> Void

  func makeUIViewController(context: Context) -> ChatDetailVC {
    let vc = ChatDetailVC(chat: chat)
    vc.configure(em: em, pref: pref, modelContext: modelContext)
    vc.onPresentInfo = onPresentInfo
    vc.onPresentPrompt = onPresentPrompt
    return vc
  }

  func updateUIViewController(_ uiViewController: ChatDetailVC, context: Context) {
    if uiViewController.chat.id != chat.id {
      uiViewController.updateChat(chat)
    }
  }
}

// MARK: - Preview

#Preview {
  LovelyPreview {
    NavigationStack {
      ChatDetailView(chat: ChatSample.manyMessages)
    }
  }
}
